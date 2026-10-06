import SwiftUI
import CardioLogCore
import CardioLogPersistence

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        Form {
            Section("Workout preferences") {
                NavigationLink("Gym & equipment") { EquipmentChooser(model: model) }
                NavigationLink("Apple Health · Off") { HealthPreviewView() }
                NavigationLink("Copy profile · AI summary") { CopyWorkoutView(workout: model.fixtures.workouts[0]) }
                LabeledContent("HR zones", value: "Unset")
                Text("Zone editing, sensor capture, Health publishing, background cues, and production exports follow in later milestones.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Sample states") {
                ForEach(model.fixtures.states) { state in Button(state.label) { model.selectState(state.id) }.accessibilityIdentifier("state-\(state.id)") }
            }
            Section { NavigationLink("About this build") { BuildInfoView() } } footer: { Text("Samples are stored in a separate SQLite preview store. No Health adapter is connected.") }
        }.scrollContentBackground(.hidden).background(Style.canvas).navigationTitle("Settings")
    }
}
struct BuildInfoView: View {
    func info(_ key: String) -> String { Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "Unknown" }
    var body: some View {
        Form {
            Section("CardioLog") {
                LabeledContent("Version", value: info("CFBundleShortVersionString"))
                LabeledContent("Build", value: info("CFBundleVersion"))
                LabeledContent("Channel", value: info("CardioLogChannel"))
                LabeledContent("Commit", value: info("CardioLogCommit"))
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                LabeledContent("Schema", value: String(PreviewRepository.schemaVersion))
            }
            Section { Text("Milestone 1 · Native shell\nFixture-backed design preview. Simulated workouts cannot publish to Health.") }
            #if CARDIOLOG_DEV
            Section("Developer diagnostics") { Text("GRDB preview store · schema v1\nSource: deterministic fixtures\nSensor: simulation\nHealth writes: disabled") }
            #endif
        }.navigationTitle("About this build")
    }
}

#Preview("Timers") { RootView(model: AppModel(fixtures: try! FixtureLibrary.load())) }
#Preview("Work") {
    let model = AppModel(fixtures: try! FixtureLibrary.load())
    model.start(elapsed: 780, paused: true)
    return LiveView(model: model)
}
