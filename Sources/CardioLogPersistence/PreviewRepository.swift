import Foundation
import GRDB
import CardioLogCore

/// Serialized, transactional preview storage. A future real-session repository must use a different file.
public actor PreviewRepository {
    public static let schemaVersion = 1
    private let database: DatabaseQueue
    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        #endif
        database = try DatabaseQueue(path: directory.appendingPathComponent("preview.sqlite").path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_preview_sessions") { db in
            try db.create(table: "preview_workouts") { table in
                table.primaryKey("id", .text)
                table.column("payload", .blob).notNull()
                table.column("startedAt", .text).notNull()
            }
            try db.create(table: "preview_metadata") { table in
                table.primaryKey("key", .text)
                table.column("value", .text).notNull()
            }
        }
        try migrator.migrate(database)
    }
    public func seedIfNeeded(_ workouts: [Workout]) throws {
        guard workouts.allSatisfy(\.isSimulation) else { throw StoreError.realDataInPreview }
        let payloads = try workouts.map { ($0, try JSONEncoder().encode($0)) }
        try database.write { db in
            guard try String.fetchOne(db, sql: "SELECT value FROM preview_metadata WHERE key = 'seeded'") == nil else { return }
            for (workout, data) in payloads {
                try db.execute(sql: "INSERT INTO preview_workouts (id, payload, startedAt) VALUES (?, ?, ?)", arguments: [workout.id, data, workout.startedAt])
            }
            try db.execute(sql: "INSERT INTO preview_metadata VALUES ('seeded', '1')")
        }
    }
    public func save(_ workout: Workout) throws {
        guard workout.isSimulation else { throw StoreError.realDataInPreview }
        let data = try JSONEncoder().encode(workout)
        try database.write { db in
            try db.execute(sql: "INSERT INTO preview_workouts (id, payload, startedAt) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, startedAt = excluded.startedAt", arguments: [workout.id, data, workout.startedAt])
        }
    }
    public func workouts() throws -> [Workout] {
        try database.read { db in
            try Data.fetchAll(db, sql: "SELECT payload FROM preview_workouts ORDER BY startedAt DESC, id").map { try JSONDecoder().decode(Workout.self, from: $0) }
        }
    }
    public enum StoreError: Error { case realDataInPreview }
}
