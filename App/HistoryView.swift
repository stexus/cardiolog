import SwiftUI
import Charts
import CardioLogCore

struct HistoryView: View {
    @Bindable var model: AppModel
    var body: some View {
        Group {
            if model.emptyHistory || model.history.isEmpty {
                ContentUnavailableView { Label("No workouts yet", systemImage: "clock") } description: { Text("Start a sample workout to explore your timeline and interval details.") } actions: { Button("Go to Timers") { model.showTimers() } }
            } else {
                List {
                    Section { Text("Sample sessions · separate preview history").font(.caption).foregroundStyle(.secondary) }
                    ForEach(model.history) { workout in
                        Button { model.selectedWorkout = workout } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("\(String(workout.startedAt.prefix(10))) · \(workout.equipment.gym)").font(.caption).foregroundStyle(.secondary)
                                Text(workout.name).font(.headline).foregroundStyle(.primary)
                                HStack { Text("\(durationText(workout.activeSeconds)) · \(workout.completedWorkCount) work intervals"); Spacer(); Text(workout.status.capitalized).fontWeight(.semibold) }.font(.caption).foregroundStyle(.secondary)
                                PhaseStrip(intervals: workout.intervals)
                            }.padding(.vertical, 6)
                        }.accessibilityIdentifier("history-\(workout.id)")
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(Style.canvas).navigationTitle("History")
    }
}
struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var selected = 1
    @State private var copy = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(workout.status.uppercased()) · SAMPLE").font(.caption.weight(.semibold)).foregroundStyle(Style.accent)
                HStack(spacing: 25) {
                    stat("ACTIVE TIME", durationText(workout.activeSeconds))
                    stat("WORK DONE", "\(workout.completedWorkCount) / \(workout.plannedWorkCount)")
                    stat("HEALTH", "Local only")
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Heart rate").font(.headline); Spacer(); Text("bpm · active time").font(.caption).foregroundStyle(.secondary) }
                    chart.frame(height: 180)
                    Text(workout.samples.isEmpty ? "No HR recorded for this sample session." : workout.gaps.isEmpty ? "Illustrative sample readings. Tap an interval below." : "Shaded gap: missing HR. Tap an interval below.").font(.caption).foregroundStyle(.secondary)
                }.padding(16).background(Style.card, in: RoundedRectangle(cornerRadius: 20))
                if workout.intervals.indices.contains(selected) {
                    let row = workout.intervals[selected]
                    let metrics = PreviewMetrics(samples: workout.samples(for: selected), start: workout.start(of: selected), duration: row.actualSeconds)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Text("\(row.role.label) \(row.repetition.map(String.init) ?? "")").font(.headline); Spacer(); Text("\(durationText(row.actualSeconds)) actual").font(.caption) }
                        Text("\(row.settings.summary) · entered").font(.caption).foregroundStyle(.secondary)
                        HStack { stat("AVERAGE", metrics.averageText); Spacer(); stat("MAXIMUM", metrics.maximumText); Spacer(); stat("END HR", metrics.endText) }
                        Text("\(Int(metrics.coverage * 100))% sample coverage · preview metrics").font(.caption).foregroundStyle(.secondary)
                    }.padding(16).background(Style.card, in: RoundedRectangle(cornerRadius: 20))
                }
                Text("INTERVALS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { index, row in
                    Button { selected = index } label: {
                        HStack { Text("\(row.role.label) \(row.repetition.map(String.init) ?? "")"); Spacer(); VStack(alignment: .trailing) { Text(durationText(row.actualSeconds)).monospacedDigit(); Text(row.settings.summary).font(.caption2) } }.font(.subheadline).foregroundStyle(.primary).padding(13).frame(maxWidth: .infinity).background(selected == index ? Style.accent.opacity(0.14) : Style.card, in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityIdentifier("interval-\(index)")
                }
                HStack {
                    Button("Copy Workout", systemImage: "doc.on.doc") { copy = true }.buttonStyle(.glassProminent).foregroundStyle(Color(.systemBackground)).controlSize(.large)
                    ShareLink(item: workout.copyText()) { Label("Share sample", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                }
                Text("\(workout.equipment.gym) · \(workout.equipment.name)\nSample data · never eligible for Health publishing.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Style.canvas).navigationTitle(workout.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() } }
        .sheet(isPresented: $copy) { CopyWorkoutView(workout: workout) }
    }
    func stat(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption2).foregroundStyle(.secondary); Text(value).font(.title3.weight(.semibold)).monospacedDigit() } }
    var chart: some View {
        Chart {
            ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { index, row in
                RectangleMark(xStart: .value("Start", workout.start(of: index)), xEnd: .value("End", workout.start(of: index) + row.actualSeconds), yStart: .value("Low", 90), yEnd: .value("High", 190)).foregroundStyle(Style.phase(row.role).opacity(index == selected ? 0.22 : 0.07))
            }
            ForEach(Array(workout.gaps.enumerated()), id: \.offset) { _, gap in RectangleMark(xStart: .value("Gap start", gap.start), xEnd: .value("Gap end", gap.end), yStart: .value("Low", 90), yEnd: .value("High", 190)).foregroundStyle(.gray.opacity(0.3)) }
            ForEach(Array(workout.samples.enumerated()), id: \.offset) { _, sample in
                LineMark(x: .value("Active seconds", sample.elapsed), y: .value("Heart rate", sample.bpm), series: .value("Segment", sample.segment)).foregroundStyle(.red.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 2))
            }
        }.chartYScale(domain: 90...190).chartXScale(domain: 0...max(1, workout.activeSeconds))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in AxisGridLine(); AxisValueLabel { if let seconds = value.as(Double.self) { Text(durationText(seconds)) } } } }
        .chartOverlay { proxy in GeometryReader { geometry in Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { location in
            guard let frame = proxy.plotFrame, let seconds: Double = proxy.value(atX: location.x - geometry[frame].origin.x) else { return }
            if let index = workout.intervals.indices.first(where: { seconds >= workout.start(of: $0) && seconds < workout.start(of: $0) + workout.intervals[$0].actualSeconds }) { selected = index }
        } } }
        .accessibilityLabel("Heart rate aligned to intervals. Use interval buttons below for textual statistics.")
    }
}
struct CopyWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @AppStorage("preview.copy.equipment") private var equipment = true
    @AppStorage("preview.copy.hr") private var hr = true
    @AppStorage("preview.copy.recovery") private var recovery = false
    @AppStorage("preview.copy.notes") private var notes = true
    @State private var copied = false
    var text: String { workout.copyText(equipment: equipment, hr: hr, recovery: recovery, notes: notes) }
    var body: some View {
        NavigationStack {
            Form {
                Section("AI summary · saved copy profile") { Toggle("Gym & entered equipment settings", isOn: $equipment); Toggle("Average, maximum, end HR & coverage", isOn: $hr); Toggle("Warm-up, recovery & cooldown rows", isOn: $recovery); Toggle("Notes", isOn: $notes) }
                Section("Text preview") { Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                Button(copied ? "Copied sample text" : "Copy sample text") { UIPasteboard.general.string = text; copied = true }
            }.navigationTitle("Copy Workout").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }
    }
}
