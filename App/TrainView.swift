import SwiftUI
import CardioLogCore

struct TemplateListView: View {
    @Bindable var model: AppModel
    @State private var draft: WorkoutTemplate?

    var body: some View {
        List {
            Section {
                ForEach(model.templates) { template in
                    Button { model.selectTemplate(template) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: template.activity == "bike" ? "figure.indoor.cycle" : "figure.run")
                                .font(.title2).foregroundStyle(Style.accent).frame(width: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(template.name).font(.headline).foregroundStyle(.primary)
                                Text("\(template.activity == "bike" ? "Indoor bike" : "Treadmill") · \(durationText(template.totalSeconds))")
                                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                                if template.id == model.template.id {
                                    Text("Last used").font(.caption).foregroundStyle(Style.accent)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }.buttonStyle(.plain).accessibilityIdentifier("template-\(template.id)")
                }
            } header: { Text("Saved templates") } footer: { Text("Choose a timer to see its workout. Your last-used template opens automatically next time.") }
        }
        .scrollContentBackground(.hidden).background(Style.canvas)
        .navigationTitle("Timers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New template", systemImage: "plus") {
                    var value = model.fixtures.templates[0]
                    value.id = UUID().uuidString; value.name = "My workout"; value.repetitions = 1
                    draft = value
                }.accessibilityIdentifier("new-template")
            }
        }
        .sheet(item: $draft) { value in TemplateEditor(template: value) { model.saveTemplate($0) } }
    }
}

/// The selected timer's setup; browsing other timers belongs to the parent list.
struct TrainView: View {
    @Bindable var model: AppModel
    @State private var draft: WorkoutTemplate?
    @State private var chooseEquipment = false
    @State private var healthInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Label(model.template.activity == "bike" ? "INDOOR BIKE" : "TREADMILL", systemImage: model.template.activity == "bike" ? "figure.indoor.cycle" : "figure.run")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Edit") { draft = model.template }.accessibilityIdentifier("edit-template")
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(durationText(model.template.totalSeconds)).font(.largeTitle.bold()).monospacedDigit()
                        Text("planned active time").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(model.template.repetitions) \(model.template.repetitions == 1 ? "effort" : "efforts") · \(durationText(model.template.workSeconds)) work\(model.template.recoverySeconds > 0 ? " / \(durationText(model.template.recoverySeconds)) recovery" : "")")
                        .font(.subheadline).foregroundStyle(.secondary)
                    PhaseStrip(intervals: (try? model.template.expanded()) ?? [])
                }.padding(20).background(Style.hero, in: RoundedRectangle(cornerRadius: 22))

                Text("BEFORE YOU BEGIN").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Button { chooseEquipment = true } label: {
                    HStack {
                        Image(systemName: "building.2")
                        VStack(alignment: .leading) {
                            Text(model.equipment.gym).fontWeight(.semibold)
                            Text(model.equipment.name).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "chevron.right")
                    }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Style.card, in: RoundedRectangle(cornerRadius: 18))
                }.foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Heart rate").fontWeight(.semibold)
                            Text(sensorDescription(model.sensor)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu("Manage") {
                            Button("Polar H10 · simulated") { model.sensor = "connected" }
                            Button("Continue without HR") { model.sensor = "none" }
                            Button("Disconnected / stale") { model.sensor = "disconnected" }
                        }
                    }
                    Divider()
                    Button { healthInfo = true } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Apple Health").fontWeight(.semibold)
                                Text("Off · samples stay in preview").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right")
                        }.foregroundStyle(.primary)
                    }
                }.padding(17).background(Style.card, in: RoundedRectangle(cornerRadius: 18))

                Text("TIMER PREVIEW").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach((try? model.template.expanded()) ?? []) { interval in
                        VStack(spacing: 0) {
                            HStack(alignment: .top) {
                                Circle().fill(Style.phase(interval.role)).frame(width: 8, height: 8).padding(.top, 7)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(interval.role.label)\(interval.repetition.map { " · \($0) of \(model.template.repetitions)" } ?? "")").font(.subheadline.weight(.semibold))
                                    Text(interval.settings.summary).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(durationText(interval.plannedSeconds)).font(.subheadline).monospacedDigit()
                            }.padding(16)
                            Divider().padding(.leading, 32)
                        }
                    }
                }.background(Style.card, in: RoundedRectangle(cornerRadius: 18))
            }.padding(20)
        }
        .background(Style.canvas)
        .navigationTitle(model.template.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Template options", systemImage: "ellipsis.circle") {
                    Button("Edit template") { draft = model.template }
                    Button("Duplicate template", systemImage: "plus.square.on.square") {
                        var value = model.template; value.id = UUID().uuidString; value.name += " copy"; draft = value
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Button { model.start() } label: {
                    Label(model.session == nil ? "Start sample workout" : "Return to workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).frame(minHeight: 30)
                }
                .buttonStyle(.glassProminent).foregroundStyle(Color(.systemBackground))
                .controlSize(.large).accessibilityIdentifier("start-workout")
                Text("Sample workout · Apple Health off").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.vertical, 10)
                .background(LinearGradient(colors: [Style.canvas.opacity(0), Style.canvas], startPoint: .top, endPoint: .bottom))
        }
        .sheet(item: $draft) { value in TemplateEditor(template: value) { model.saveTemplate($0) } }
        .sheet(isPresented: $chooseEquipment) { EquipmentChooser(model: model) }
        .sheet(isPresented: $healthInfo) { HealthPreviewView() }
    }
}
func sensorDescription(_ state: String) -> String {
    switch state { case "none": "No HR sensor · timer available"; case "disconnected": "Disconnected · last reading is stale"; default: "Polar H10 · simulated connection" }
}
struct PhaseStrip: View {
    let intervals: [Interval]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                HStack(spacing: 3) { ForEach(intervals) { row in RoundedRectangle(cornerRadius: 3).fill(Style.phase(row.role).opacity(row.role == .work ? 1 : 0.45)).frame(width: max(2, (proxy.size.width - Double(max(0, intervals.count - 1)) * 3) * row.plannedSeconds / max(1, intervals.reduce(0) { $0 + $1.plannedSeconds }))) } }
            }.frame(height: 22).accessibilityLabel("Workout phase sequence")
            Text("Warm-up / cool · Work · Recovery").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var template: WorkoutTemplate
    let save: (WorkoutTemplate) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $template.name) }
                Section("Optional phases · seconds") { duration("Warm-up", $template.warmupSeconds); duration("Cooldown", $template.cooldownSeconds) }
                Section("Repeated group · seconds") {
                    duration("Work", $template.workSeconds); duration("Recovery", $template.recoverySeconds)
                    Stepper("Repetitions: \(template.repetitions)", value: $template.repetitions, in: 1...99)
                    Toggle("Recovery after final repetition", isOn: $template.finalRecovery)
                }
                Section("Entered work settings") { EquipmentFields(settings: $template.workSettings, bike: template.activity == "bike") }
                Section("Entered recovery settings") { EquipmentFields(settings: $template.recoverySettings, bike: template.activity == "bike") }
                Section("Sequence preview") { PhaseStrip(intervals: (try? template.expanded()) ?? []); Text("Planned active time: \(durationText(template.totalSeconds))").monospacedDigit() }
            }.navigationTitle("Edit template").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save(template); dismiss() }.disabled((try? template.expanded()) == nil || template.name.trimmingCharacters(in: .whitespaces).isEmpty) } }
        }
    }
    func duration(_ title: String, _ value: Binding<Double>) -> some View { HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90) } }
}
struct EquipmentFields: View {
    @Binding var settings: EquipmentSettings
    let bike: Bool
    func field(_ name: String, _ value: Binding<Double?>) -> some View { HStack { Text(name); Spacer(); TextField(name, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 95) } }
    var body: some View {
        if bike { field("Resistance level", $settings.resistance); field("Cadence (rpm)", $settings.cadence) }
        else { field("Speed (mph)", $settings.speed); field("Incline (%)", $settings.incline) }
    }
}
struct EquipmentChooser: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    var body: some View {
        NavigationStack { List { ForEach(model.fixtures.equipment.filter { $0.activity == model.template.activity }) { e in Button { model.selectEquipment(e); dismiss() } label: { HStack { VStack(alignment: .leading) { Text(e.name); Text(e.gym).font(.caption).foregroundStyle(.secondary) }; Spacer(); if e.id == model.equipment.id { Image(systemName: "checkmark") } } } } }.navigationTitle("Gym & equipment").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } } }
    }
}
struct HealthPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { Form { Section { Toggle("Publish this sample to Apple Health", isOn: .constant(false)).disabled(true) } footer: { Text("Sample data is never eligible. In the finished app, choose whether CardioLog or your Watch saves a real workout. Local recording will always be available without Health.") } }.navigationTitle("Apple Health").toolbar { Button("Done") { dismiss() } } }
    }
}
