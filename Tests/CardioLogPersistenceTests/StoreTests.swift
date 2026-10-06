import Testing
import Foundation
import CardioLogCore
@testable import CardioLogPersistence

@Test func sessionsSurviveReopenAndMigrationsAreIdempotent() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fixtures = try FixtureLibrary.load()
    let repository = try PreviewRepository(directory: directory)
    try await repository.seedIfNeeded(fixtures.workouts)
    var workout = fixtures.workouts[0]; workout.id = "saved-session"; workout.notes = "Saved independently of the fixture"
    try await repository.save(workout)
    let reopened = try PreviewRepository(directory: directory)
    try await reopened.seedIfNeeded(fixtures.workouts)
    let rows = try await reopened.workouts()
    #expect(rows.count == 4)
    #expect(rows.first { $0.id == "saved-session" } == workout)
    workout.notes = "Updated note"
    try await reopened.save(workout)
    #expect(try await reopened.workouts().count == 4)
}
@Test func realWorkoutsCannotEnterPreviewStore() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try PreviewRepository(directory: directory)
    var workout = try FixtureLibrary.load().workouts[0]; workout.isSimulation = false
    await #expect(throws: PreviewRepository.StoreError.self) { try await repository.save(workout) }
    #expect(try await repository.workouts().isEmpty)
}
