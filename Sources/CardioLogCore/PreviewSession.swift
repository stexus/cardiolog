import Foundation

public protocol ElapsedClock: Sendable { func now() -> Double }
public struct MonotonicClock: ElapsedClock {
    public init() {}
    public func now() -> Double { ProcessInfo.processInfo.systemUptime }
}
public protocol HeartRateSource: Sendable { func reading(at elapsed: Double) -> HRSample? }
public struct FixtureHeartRateSource: HeartRateSource {
    public let samples: [HRSample]
    public init(samples: [HRSample]) { self.samples = samples }
    public func reading(at elapsed: Double) -> HRSample? {
        samples.last { $0.elapsed <= elapsed && elapsed - $0.elapsed < 15 }
    }
}

/// A foreground design simulation, not the durable recording engine planned for Milestone 3.
public struct PreviewSession: Sendable {
    public var template: WorkoutTemplate
    public var equipment: Equipment
    public private(set) var intervals: [Interval]
    public private(set) var paused: Bool
    private var accumulated: Double
    private var anchor: Double
    private let clock: any ElapsedClock
    public let startedAt: String

    public init(template: WorkoutTemplate, equipment: Equipment, elapsed: Double = 0, paused: Bool = false, clock: any ElapsedClock = MonotonicClock()) throws {
        self.template = template; self.equipment = equipment
        intervals = try template.expanded(); self.paused = paused
        accumulated = elapsed; self.clock = clock; anchor = clock.now()
        startedAt = ISO8601DateFormatter().string(from: Date())
    }
    public var total: Double { intervals.reduce(0) { $0 + $1.plannedSeconds } }
    public var elapsed: Double { min(total, accumulated + (paused ? 0 : max(0, clock.now() - anchor))) }
    public var currentIndex: Int {
        var end = 0.0
        for (index, interval) in intervals.enumerated() {
            end += interval.plannedSeconds
            if elapsed < end { return index }
        }
        return max(0, intervals.count - 1)
    }
    public var remaining: Double { max(0, intervals.prefix(currentIndex + 1).reduce(0) { $0 + $1.plannedSeconds } - elapsed) }
    public var futureWorkIndices: [Int] { intervals.indices.filter { $0 > currentIndex && intervals[$0].role == .work } }
    public mutating func togglePause() {
        accumulated = elapsed; anchor = clock.now(); paused.toggle()
    }
    public mutating func updateFuture(settings: EquipmentSettings, nextOnly: Bool) {
        for index in nextOnly ? Array(futureWorkIndices.prefix(1)) : futureWorkIndices { intervals[index].settings = settings }
    }
    @discardableResult public mutating func addRepetition() -> Bool {
        // Cannot insert before a cooldown that has already started.
        guard intervals[currentIndex].role != .cooldown, elapsed < total else { return false }
        let insertion = intervals.firstIndex { $0.role == .cooldown } ?? intervals.count
        let count = intervals.filter { $0.role == .work }.count
        var added: [Interval] = []
        func make(_ role: PhaseRole, _ seconds: Double, _ repetition: Int) -> Interval {
            Interval(id: UUID().uuidString, role: role, repetition: repetition, plannedSeconds: seconds, actualSeconds: 0, settings: role == .work ? template.workSettings : template.recoverySettings)
        }
        if !template.finalRecovery && template.recoverySeconds > 0 { added.append(make(.recovery, template.recoverySeconds, count)) }
        added.append(make(.work, template.workSeconds, count + 1))
        if template.finalRecovery && template.recoverySeconds > 0 { added.append(make(.recovery, template.recoverySeconds, count + 1)) }
        intervals.insert(contentsOf: added, at: insertion)
        return true
    }
    public func finish() -> Workout {
        var remaining = elapsed
        let actual = intervals.map { interval in
            var result = interval; result.actualSeconds = min(result.plannedSeconds, max(0, remaining))
            remaining -= result.actualSeconds; return result
        }
        // A newly simulated session has no collected HR. Historical fixture traces must never be attached as new observations.
        return Workout(id: UUID().uuidString, name: template.name, templateID: template.id, startedAt: startedAt, status: elapsed >= total ? "completed" : "partial", isSimulation: true, equipment: equipment, activeSeconds: elapsed, intervals: actual, samples: [], gaps: [], notes: "Simulated session. No sensor data was recorded.")
    }
}
