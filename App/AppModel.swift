import SwiftUI
import CardioLogCore
import CardioLogPersistence

@MainActor @Observable final class AppModel {
    let fixtures: FixtureLibrary
    var templates: [WorkoutTemplate]
    var template: WorkoutTemplate
    var timerPath: [String] = []
    @ObservationIgnored private let preferences: UserDefaults
    var equipment: Equipment
    var sensor = "connected"
    var session: PreviewSession?
    var history: [Workout] = []
    var selectedWorkout: Workout?
    var tab = 0
    var showLive = false
    var emptyHistory = false
    var error: String?
    var loaded = false
    private var repository: PreviewRepository?

    init(fixtures: FixtureLibrary, preferences: UserDefaults = .standard) {
        self.fixtures = fixtures
        self.preferences = preferences
        if ProcessInfo.processInfo.arguments.contains("--reset-preview-preferences") {
            preferences.removeObject(forKey: "preview.templates.v1")
            preferences.removeObject(forKey: "preview.lastTemplateID")
        }
        let saved = preferences.data(forKey: "preview.templates.v1")
            .flatMap { try? JSONDecoder().decode([WorkoutTemplate].self, from: $0) }
        let available = saved.flatMap { items in
            !items.isEmpty && items.allSatisfy { (try? $0.expanded()) != nil } ? items : nil
        } ?? fixtures.templates
        templates = available
        let selected = available.first { $0.id == preferences.string(forKey: "preview.lastTemplateID") } ?? available[0]
        template = selected
        equipment = fixtures.equipment.first { $0.id == selected.equipmentID } ?? fixtures.equipment[0]
    }
    func load() async {
        guard !loaded else { return }; loaded = true
        do {
            let directory = URL.applicationSupportDirectory.appendingPathComponent("CardioLog/Preview", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-preview-storage"), FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            let repository = try PreviewRepository(directory: directory)
            self.repository = repository
            try await repository.seedIfNeeded(fixtures.workouts)
            history = try await repository.workouts()
            timerPath = [template.id]
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--preview-state"), args.indices.contains(index + 1) { selectState(args[index + 1]) }
        } catch { self.error = "Preview storage could not open: \(error.localizedDescription)" }
    }
    func selectTemplate(_ value: WorkoutTemplate, remember: Bool = true) {
        template = value
        equipment = fixtures.equipment.first { $0.id == value.equipmentID } ?? equipment
        timerPath = [value.id]
        if remember { preferences.set(value.id, forKey: "preview.lastTemplateID") }
    }
    func saveTemplate(_ value: WorkoutTemplate) {
        if let index = templates.firstIndex(where: { $0.id == value.id }) { templates[index] = value }
        else { templates.append(value) }
        do { preferences.set(try JSONEncoder().encode(templates), forKey: "preview.templates.v1") }
        catch { self.error = "Could not save the preview template: \(error.localizedDescription)" }
        selectTemplate(value)
    }
    func selectEquipment(_ value: Equipment) {
        equipment = value
        template.equipmentID = value.id
        saveTemplate(template)
    }
    func showTimers() { tab = 0; timerPath = [] }
    func start(elapsed: Double = 0, paused: Bool = false, remember: Bool = true) {
        guard session == nil else { showLive = true; return }
        if remember { saveTemplate(template) }
        do { session = try PreviewSession(template: template, equipment: equipment, elapsed: elapsed, paused: paused); showLive = true }
        catch { self.error = "Enter a positive work duration and 1–99 repetitions." }
    }
    func finish() async {
        guard let session, let repository else { error = "Preview storage is unavailable. Your session remains open."; return }
        let workout = session.finish()
        do {
            try await repository.save(workout)
            history = try await repository.workouts()
            self.session = nil; showLive = false; emptyHistory = false; tab = 1
            selectedWorkout = workout
        } catch { self.error = "Could not save your sample: \(error.localizedDescription)" }
    }
    func selectState(_ id: String) {
        guard let state = fixtures.states.first(where: { $0.id == id }) else { return }
        showLive = false; session = nil; selectedWorkout = nil; emptyHistory = false; tab = 0
        selectTemplate(fixtures.templates[0], remember: false); sensor = state.sensor
        switch id {
        case "work", "recovery", "paused", "no-hr", "disconnected": start(elapsed: state.elapsed, paused: id == "paused", remember: false)
        case "empty": tab = 1; emptyHistory = true
        case "completed": tab = 1; selectedWorkout = fixtures.workouts[0]
        case "partial": tab = 1; selectedWorkout = fixtures.workouts[2]
        default: break
        }
    }
}

@main struct CardioLogApp: App {
    @State private var model: AppModel?
    @State private var failure: String?
    private var previewAppearance: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--preview-appearance"), args.indices.contains(i + 1) else { return nil }
        return args[i + 1] == "dark" ? .dark : .light
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if let model { RootView(model: model) }
                else if let failure { ContentUnavailableView("Could not load sample data", systemImage: "exclamationmark.triangle", description: Text(failure)) }
                else { ProgressView().task { do { model = AppModel(fixtures: try FixtureLibrary.load()) } catch { failure = error.localizedDescription } } }
            }.tint(Style.accent)
            .preferredColorScheme(previewAppearance)
        }
    }
}

enum Style {
    static let accent = Color("AccentColor")
    static let canvas = Color("CanvasColor")
    static let card = Color("CardColor")
    static let hero = Color("HeroColor")
    static func phase(_ role: PhaseRole) -> Color {
        switch role { case .work: accent; case .recovery: Color("RecoveryColor"); case .warmup, .cooldown: Color("WarmupColor") }
    }
}
struct SampleBanner: View {
    var body: some View { Text("SAMPLE DATA · Local preview only").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 7).background(.bar).accessibilityIdentifier("sample-banner") }
}
struct RootView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            SampleBanner()
            TabView(selection: Binding(get: { model.tab }, set: { value in
                if value == 0 { model.showTimers() } else { model.tab = value }
            })) {
                Tab("Timers", systemImage: "timer", value: 0) {
                    NavigationStack(path: $model.timerPath) {
                        TemplateListView(model: model)
                            .navigationDestination(for: String.self) { _ in TrainView(model: model) }
                    }
                }
                Tab("History", systemImage: "clock.arrow.circlepath", value: 1) { NavigationStack { HistoryView(model: model) } }
                Tab("Settings", systemImage: "gearshape", value: 2) { NavigationStack { SettingsView(model: model) } }
            }
            .safeAreaInset(edge: .bottom) {
                if model.session != nil && (model.tab != 0 || model.timerPath.isEmpty) { Button("Return to active sample workout") { model.showLive = true }.buttonStyle(.glassProminent).foregroundStyle(Color(.systemBackground)).padding(8) }
            }
        }.background(Style.canvas)
        .fullScreenCover(isPresented: $model.showLive) { LiveView(model: model) }
        .sheet(item: $model.selectedWorkout) { workout in NavigationStack { WorkoutDetailView(workout: workout) } }
        .alert("CardioLog", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .task { await model.load() }
    }
}
