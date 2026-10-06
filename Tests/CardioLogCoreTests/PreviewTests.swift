import Testing
import Foundation
@testable import CardioLogCore

private final class TestClock: ElapsedClock, @unchecked Sendable {
    // Each test owns one clock; mutation is intentionally confined to that test.
    var instant = 100.0
    func now() -> Double { instant }
}
@Test func fixtureExpansionAndValidation() throws {
    let library = try FixtureLibrary.load()
    var template = library.templates[0]
    let rows = try template.expanded()
    #expect(rows.filter { $0.role == .work }.count == 4)
    #expect(rows.filter { $0.role == .recovery }.count == 3)
    #expect(template.totalSeconds == 2100)
    template.finalRecovery = true
    #expect(try template.expanded().filter { $0.role == .recovery }.count == 4)
    template.warmupSeconds = 0; template.cooldownSeconds = 0
    #expect(try template.expanded().first?.role == .work)
    template.repetitions = 0
    #expect(throws: TemplateError.self) { try template.expanded() }
    template.repetitions = 1; template.workSeconds = -1
    #expect(throws: TemplateError.self) { try template.expanded() }
    template.workSeconds = 0
    #expect(throws: TemplateError.self) { try template.expanded() }
}
@Test func monotonicPauseDelayedRefreshAndPartialFinish() throws {
    let library = try FixtureLibrary.load(), clock = TestClock()
    var session = try PreviewSession(template: library.templates[0], equipment: library.equipment[0], clock: clock)
    clock.instant += 570
    #expect(session.currentIndex == 2)
    #expect(session.remaining == 150)
    session.togglePause(); clock.instant += 400
    #expect(session.elapsed == 570)
    session.togglePause(); clock.instant += 30
    #expect(session.elapsed == 600)
    let workout = session.finish()
    #expect(workout.status == "partial")
    #expect(workout.activeSeconds == 600)
    #expect(workout.intervals[2].actualSeconds == 60)
    #expect(workout.intervals[3].actualSeconds == 0)
    #expect(workout.samples.isEmpty)
    #expect(workout.isSimulation && !workout.canPublishToHealth)
}
@Test func futureSettingsAndAddedRepetitionRespectBoundaries() throws {
    let library = try FixtureLibrary.load()
    var session = try PreviewSession(template: library.templates[0], equipment: library.equipment[0], elapsed: 570, paused: true)
    let original = session.intervals
    var settings = library.templates[0].workSettings; settings.speed = 7.2
    session.updateFuture(settings: settings, nextOnly: true)
    #expect(session.intervals[3].settings.speed == 7.2)
    #expect(session.intervals[5].settings.speed == 6.5)
    #expect(session.intervals[1] == original[1])
    session.updateFuture(settings: settings, nextOnly: false)
    #expect(session.intervals[7].settings.speed == 7.2)
    #expect(session.intervals[4] == original[4])
    let added = session.addRepetition()
    #expect(added)
    #expect(session.intervals.suffix(3).map(\.role) == [.recovery, .work, .cooldown])
    #expect(session.total == 2520)
    var final = library.templates[0]; final.finalRecovery = true
    var withFinal = try PreviewSession(template: final, equipment: library.equipment[0], paused: true)
    let addedFinal = withFinal.addRepetition()
    #expect(addedFinal)
    #expect(withFinal.intervals.suffix(3).map(\.role) == [.work, .recovery, .cooldown])
    var cooling = try PreviewSession(template: library.templates[0], equipment: library.equipment[0], elapsed: 1900, paused: true)
    let addedDuringCooldown = cooling.addRepetition()
    #expect(!addedDuringCooldown)
}
@Test func gapsNeverBecomeZeroOrIndefinitelyFresh() throws {
    let workout = try FixtureLibrary.load().workouts[0]
    let source = FixtureHeartRateSource(samples: workout.samples)
    #expect(source.reading(at: 1060) == nil)
    #expect(source.reading(at: 1120) != nil)
    let metrics = PreviewMetrics(samples: [.init(elapsed: 0, bpm: 160, segment: 0)], start: 0, duration: 240)
    #expect(metrics.average == 160)
    #expect(metrics.end == nil)
    #expect(metrics.coverage == 15.0 / 240)
    #expect(workout.copyText().contains("SAMPLE DATA"))
    #expect(!workout.copyText(equipment: false, hr: false).contains("mph"))
    #expect(!workout.copyText(equipment: false, hr: false).contains("bpm"))
}
