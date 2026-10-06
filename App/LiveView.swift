import SwiftUI
import CardioLogCore

struct LiveView: View {
    @Bindable var model: AppModel
    @State private var confirmFinish = false
    @State private var editNext = false
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    if let session = model.session {
                        ScrollView {
                            let landscape = geometry.size.width > geometry.size.height
                            let layout = landscape ? AnyLayout(HStackLayout(alignment: .top, spacing: 25)) : AnyLayout(VStackLayout(spacing: 20))
                            layout {
                                countdown(session, compact: landscape).frame(maxWidth: .infinity)
                                controls(session, compact: landscape).frame(maxWidth: .infinity)
                            }.padding(landscape ? 10 : 22)
                        }
                        .onChange(of: session.elapsed >= session.total) { _, ended in if ended { Task { await model.finish() } } }
                    }
                }
            }.background(Style.canvas)
            .safeAreaInset(edge: .top, spacing: 0) { SampleBanner() }
            .navigationTitle(model.session?.template.name ?? "Sample workout").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Timer", systemImage: "chevron.down") { model.showLive = false } } }
            .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) { Button("Finish & save sample") { Task { await model.finish() } }.accessibilityIdentifier("confirm-finish") } message: { Text("Your partial sample session will be saved with its actual active duration.") }
            .sheet(isPresented: $editNext) { if let session = model.session { NextSettingsView(model: model, session: session) } }
            .alert("Sample workout", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") { notice = nil } } message: { Text(notice ?? "") }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
    func countdown(_ session: PreviewSession, compact: Bool) -> some View {
        let row = session.intervals[session.currentIndex]
        return VStack(spacing: compact ? 3 : 7) {
            Text("\(session.paused ? "PAUSED" : row.role.label.uppercased())\(row.repetition.map { " · \($0) OF \(session.intervals.filter { $0.role == .work }.count)" } ?? "")").font(.subheadline.weight(.semibold)).foregroundStyle(Style.accent).padding(.top, compact ? 2 : 12)
            Text(durationText(session.remaining)).font(.system(size: compact ? 70 : 88, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.55).lineLimit(1).accessibilityIdentifier("countdown")
            Text(session.paused ? "Timer paused" : "remaining in this interval").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Label("HEART RATE", systemImage: "heart.fill").font(.caption).foregroundStyle(.red)
                HStack(alignment: .firstTextBaseline, spacing: 5) { Text(model.sensor == "connected" && !session.paused ? "162" : "—").font(.system(size: compact ? 30 : 40, weight: .semibold)).monospacedDigit(); Text("bpm").font(.subheadline).foregroundStyle(.secondary) }
                Text(session.paused ? "Paused · HR excluded" : model.sensor == "connected" ? "Simulated reading · no sensor data" : sensorDescription(model.sensor)).font(.caption).foregroundStyle(.secondary)
            }.padding(compact ? 8 : 20).frame(maxWidth: .infinity).background(Style.card, in: RoundedRectangle(cornerRadius: 20)).padding(.top, compact ? 2 : 12)
        }
    }
    func controls(_ session: PreviewSession, compact: Bool) -> some View {
        let index = session.currentIndex, row = session.intervals[index]
        return VStack(spacing: compact ? 8 : 16) {
            VStack(alignment: .leading, spacing: compact ? 3 : 10) { Text("ENTERED SETTINGS").font(.caption).foregroundStyle(.secondary); Text(row.settings.summary).font(compact ? .headline : .title2.weight(.semibold)).monospacedDigit() }.padding(compact ? 8 : 18).frame(maxWidth: .infinity, alignment: .leading).background(Style.card, in: RoundedRectangle(cornerRadius: 20))
            HStack { VStack(alignment: .leading, spacing: 4) { Text("UP NEXT").font(.caption).foregroundStyle(.secondary); Text(index + 1 < session.intervals.count ? "\(session.intervals[index + 1].role.label) · \(durationText(session.intervals[index + 1].plannedSeconds))" : "Workout complete").font(.headline) }; Spacer(); Button("Edit Next") { editNext = true } }.padding(compact ? 8 : 16).background(Style.card, in: RoundedRectangle(cornerRadius: 16))
            HStack { Text("\(durationText(session.elapsed)) active"); Spacer(); Text("\(durationText(session.total)) planned") }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            ProgressView(value: session.elapsed, total: session.total)
            Button { model.session?.togglePause() } label: { Label(session.paused ? "Resume" : "Pause", systemImage: session.paused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity) }.buttonStyle(.glassProminent).foregroundStyle(Color(.systemBackground)).controlSize(.large).accessibilityIdentifier("pause-resume")
            HStack { Button("Add Interval", systemImage: "plus") { if model.session?.addRepetition() == true { notice = "Work interval added. Planned active time: \(durationText(model.session?.total ?? 0))." } else { notice = "Cooldown has begun; start another workout instead." } }.buttonStyle(.bordered); Spacer(); Button("Finish", role: .destructive) { confirmFinish = true }.accessibilityIdentifier("finish-workout").buttonStyle(.bordered).tint(.red) }
        }
    }
}
struct NextSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var settings: EquipmentSettings
    @State private var nextOnly = false
    init(model: AppModel, session: PreviewSession) {
        self.model = model
        _settings = State(initialValue: session.futureWorkIndices.first.map { session.intervals[$0].settings } ?? session.template.workSettings)
    }
    var body: some View {
        NavigationStack {
            Form {
                if let session = model.session, !session.futureWorkIndices.isEmpty {
                    Section { EquipmentFields(settings: $settings, bike: session.template.activity == "bike") }
                    Section { Picker("Apply to", selection: $nextOnly) { Text("Remaining work intervals").tag(false); Text("Next work interval only").tag(true) } }
                    Section { Text("Changes work intervals: \((nextOnly ? Array(session.futureWorkIndices.prefix(1)) : session.futureWorkIndices).compactMap { session.intervals[$0].repetition }.map(String.init).joined(separator: ", "))").font(.subheadline) } footer: { Text("Current and completed settings stay frozen. Recovery settings stay unchanged.") }
                    Button("Apply settings") { model.session?.updateFuture(settings: settings, nextOnly: nextOnly); dismiss() }
                } else {
                    Text("There are no future work intervals to edit.")
                    Button("Add Interval") { _ = model.session?.addRepetition(); dismiss() }
                }
            }.navigationTitle("Edit next work").navigationBarTitleDisplayMode(.inline).toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
