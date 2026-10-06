import Foundation

public struct EquipmentSettings: Codable, Equatable, Sendable {
    public var speed: Double?
    public var incline: Double?
    public var resistance: Double?
    public var cadence: Double?
    public var summary: String {
        if let speed { return "\(speed.formatted()) mph · \(incline.map { $0.formatted() } ?? "—")% incline" }
        if let resistance { return "Level \(resistance.formatted()) · \(cadence.map { $0.formatted() } ?? "—") rpm" }
        return "Settings not entered"
    }
}

public struct Equipment: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var gym: String
    public var name: String
    public var activity: String
    public var speedUnit: String?
}

public enum PhaseRole: String, Codable, Sendable {
    case warmup, work, recovery, cooldown
    public var label: String {
        switch self { case .warmup: "Warm-up"; case .work: "Work"; case .recovery: "Recovery"; case .cooldown: "Cooldown" }
    }
}

public struct Interval: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var role: PhaseRole
    public var repetition: Int?
    public var plannedSeconds: Double
    public var actualSeconds: Double
    public var settings: EquipmentSettings
}

public enum TemplateError: Error { case invalidDuration, invalidCount, emptyWorkout }

/// Milestone 1's editable work/recovery scaffold. A generic ordered builder follows in Milestone 3.
public struct WorkoutTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var activity: String
    public var equipmentID: String
    public var warmupSeconds: Double
    public var workSeconds: Double
    public var recoverySeconds: Double
    public var repetitions: Int
    public var finalRecovery: Bool
    public var cooldownSeconds: Double
    public var workSettings: EquipmentSettings
    public var recoverySettings: EquipmentSettings

    public func expanded() throws -> [Interval] {
        guard [warmupSeconds, workSeconds, recoverySeconds, cooldownSeconds].allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw TemplateError.invalidDuration }
        guard (1...99).contains(repetitions) else { throw TemplateError.invalidCount }
        guard workSeconds > 0 else { throw TemplateError.emptyWorkout }
        var result: [Interval] = []
        func append(_ role: PhaseRole, _ duration: Double, _ repetition: Int? = nil) {
            guard duration > 0 else { return }
            result.append(Interval(id: "\(id)-\(result.count)", role: role, repetition: repetition, plannedSeconds: duration, actualSeconds: 0, settings: role == .work ? workSettings : recoverySettings))
        }
        append(.warmup, warmupSeconds)
        for repetition in 1...repetitions {
            append(.work, workSeconds, repetition)
            if repetition < repetitions || finalRecovery { append(.recovery, recoverySeconds, repetition) }
        }
        append(.cooldown, cooldownSeconds)
        return result
    }
    public var totalSeconds: Double { (try? expanded().reduce(0) { $0 + $1.plannedSeconds }) ?? 0 }
}

public struct HRSample: Codable, Equatable, Sendable {
    public var elapsed: Double
    public var bpm: Double
    public var segment: Int
}
public struct DataGap: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var reason: String
}
public struct Workout: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var templateID: String
    public var startedAt: String
    public var status: String
    public var isSimulation: Bool
    public var equipment: Equipment
    public var activeSeconds: Double
    public var intervals: [Interval]
    public var samples: [HRSample]
    public var gaps: [DataGap]
    public var notes: String
    public var completedWorkCount: Int { intervals.filter { $0.role == .work && $0.actualSeconds >= $0.plannedSeconds }.count }
    public var plannedWorkCount: Int { intervals.filter { $0.role == .work }.count }
    public var canPublishToHealth: Bool { false } // No Health adapter is present in the shell.
    public func start(of index: Int) -> Double { intervals.prefix(index).reduce(0) { $0 + $1.actualSeconds } }
    public func samples(for index: Int) -> [HRSample] {
        let start = start(of: index), end = start + intervals[index].actualSeconds
        return samples.filter { $0.elapsed >= start && $0.elapsed < end }
    }
    public func copyText(equipment includeEquipment: Bool = true, hr: Bool = true, recovery: Bool = false, notes includeNotes: Bool = true) -> String {
        var lines = ["CardioLog · SAMPLE DATA", name, "\(startedAt) · \(status.capitalized)", "Active \(durationText(activeSeconds)) · \(completedWorkCount)/\(plannedWorkCount) work intervals completed"]
        if includeEquipment { lines.append("\(equipment.gym) · \(equipment.name)") }
        for (index, interval) in intervals.enumerated() where interval.actualSeconds > 0 && (interval.role == .work || recovery) {
            var row = "\(interval.role.label) \(interval.repetition.map(String.init) ?? "") · \(durationText(interval.actualSeconds))"
            if includeEquipment { row += " · \(interval.settings.summary) (entered)" }
            if hr {
                let metrics = PreviewMetrics(samples: samples(for: index), start: start(of: index), duration: interval.actualSeconds)
                row += " · avg \(metrics.averageText), max \(metrics.maximumText), end \(metrics.endText) bpm · \(Int(metrics.coverage * 100))% coverage"
            }
            lines.append(row)
        }
        if !gaps.isEmpty { lines.append("HR gaps: \(gaps.count). Missing readings are not zero.") }
        if includeNotes && !notes.isEmpty { lines.append(notes) }
        return lines.joined(separator: "\n")
    }
}

/// Preview-only metrics: forward duration weighting, capped at 15 seconds per sample; no interpolation over gaps.
public struct PreviewMetrics: Sendable {
    public let average: Double?
    public let maximum: Double?
    public let end: Double?
    public let coverage: Double
    public init(samples: [HRSample], start: Double, duration: Double) {
        let samples = samples.filter { $0.elapsed >= start && $0.elapsed < start + duration }.sorted { $0.elapsed < $1.elapsed }
        var weight = 0.0, sum = 0.0
        for (index, sample) in samples.enumerated() {
            let next = index + 1 < samples.count ? samples[index + 1].elapsed : start + duration
            let span = max(0, min(15, min(next, start + duration) - sample.elapsed))
            sum += sample.bpm * span; weight += span
        }
        average = weight > 0 ? sum / weight : nil
        maximum = samples.map(\.bpm).max()
        end = samples.last.flatMap { start + duration - $0.elapsed <= 15 ? $0.bpm : nil }
        coverage = duration > 0 ? min(1, weight / duration) : 0
    }
    public var averageText: String { average.map { String(Int($0.rounded())) } ?? "—" }
    public var maximumText: String { maximum.map { String(Int($0.rounded())) } ?? "—" }
    public var endText: String { end.map { String(Int($0.rounded())) } ?? "—" }
}

public struct PreviewState: Codable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var elapsed: Double
    public var sensor: String
}
public struct FixtureLibrary: Codable, Sendable {
    public var schemaVersion: Int
    public var templates: [WorkoutTemplate]
    public var equipment: [Equipment]
    public var workouts: [Workout]
    public var states: [PreviewState]
    public static func load() throws -> Self {
        guard let url = Bundle.module.url(forResource: "sessions", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        let library = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard library.schemaVersion == 1, library.workouts.allSatisfy(\.isSimulation) else { throw CocoaError(.coderReadCorrupt) }
        return library
    }
}
public func durationText(_ seconds: Double) -> String {
    let whole = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d", whole / 60, whole % 60)
}
