import Foundation
import GRDB

/// Thin wrapper around a GRDB `DatabaseWriter` that applies migrations.
/// Call sites should go through `WorkoutRepository`; this type exists so the
/// repo can be constructed against either the app's on-disk database or an
/// in-memory one for tests.
struct AppDatabase {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try migrator.migrate(writer)
    }

    /// Points at Application Support/RowTracker/db.sqlite.
    static func onDisk() throws -> AppDatabase {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory,
                              in: .userDomainMask,
                              appropriateFor: nil,
                              create: true)
            .appendingPathComponent("RowTracker", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("db.sqlite")

        var config = Configuration()
        config.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        return try AppDatabase(queue)
    }

    /// In-memory DB, used by tests.
    static func inMemory() throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let queue = try DatabaseQueue(configuration: config)
        return try AppDatabase(queue)
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_schema") { db in
            try db.execute(sql: """
                CREATE TABLE workouts (
                    id    TEXT PRIMARY KEY NOT NULL,
                    kind  TEXT NOT NULL CHECK (kind IN ('timed','distance')),
                    date  REAL NOT NULL,
                    notes TEXT NOT NULL DEFAULT ''
                )
            """)
            try db.execute(sql: """
                CREATE TABLE intervals (
                    id              TEXT PRIMARY KEY NOT NULL,
                    workout_id      TEXT NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
                    position        INTEGER NOT NULL,
                    duration_sec    REAL NOT NULL,
                    distance_meters REAL
                )
            """)
            try db.execute(sql: "CREATE INDEX idx_intervals_workout ON intervals(workout_id)")
            try db.execute(sql: "CREATE INDEX idx_workouts_date ON workouts(date DESC)")
        }
        m.registerMigration("v2_add_stroke_rate") { db in
            try db.execute(sql: "ALTER TABLE intervals ADD COLUMN stroke_rate INTEGER")
        }
        return m
    }
}
