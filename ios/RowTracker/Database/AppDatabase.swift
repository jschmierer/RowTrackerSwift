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
        try Self.migrator.migrate(writer)
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

    /// Internal (not private) so tests can migrate a database only up to an
    /// older version and then upgrade it, the way a phone does on update.
    /// Never edit a migration that has shipped: add a new one instead.
    static var migrator: DatabaseMigrator {
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
        m.registerMigration("v3_add_heart_rate_and_effort") { db in
            // Workout-level, all nullable: workouts saved before this
            // version have no heart rate or effort and show a dash.
            try db.execute(sql: """
                ALTER TABLE workouts ADD COLUMN avg_hr INTEGER
                    CHECK (avg_hr IS NULL OR avg_hr BETWEEN 30 AND 230)
            """)
            try db.execute(sql: """
                ALTER TABLE workouts ADD COLUMN max_hr INTEGER
                    CHECK (max_hr IS NULL OR max_hr BETWEEN 30 AND 230)
            """)
            try db.execute(sql: """
                ALTER TABLE workouts ADD COLUMN effort INTEGER
                    CHECK (effort IS NULL OR effort BETWEEN 0 AND 10)
            """)
        }
        m.registerMigration("v4_custom_workouts_and_rest") { db in
            // SQLite can't change a CHECK constraint in place, so rebuild
            // `workouts` to allow 'custom': create the new table, copy every
            // row, drop the old one, rename. GRDB runs migrations with
            // foreign keys off (checked before commit), so dropping the old
            // table does not cascade-delete any intervals.
            try db.execute(sql: """
                CREATE TABLE workouts_v4 (
                    id      TEXT PRIMARY KEY NOT NULL,
                    kind    TEXT NOT NULL CHECK (kind IN ('timed','distance','custom')),
                    date    REAL NOT NULL,
                    notes   TEXT NOT NULL DEFAULT '',
                    avg_hr  INTEGER CHECK (avg_hr IS NULL OR avg_hr BETWEEN 30 AND 230),
                    max_hr  INTEGER CHECK (max_hr IS NULL OR max_hr BETWEEN 30 AND 230),
                    effort  INTEGER CHECK (effort IS NULL OR effort BETWEEN 0 AND 10),
                    title   TEXT,
                    details TEXT
                )
            """)
            try db.execute(sql: """
                INSERT INTO workouts_v4 (id, kind, date, notes, avg_hr, max_hr, effort)
                SELECT id, kind, date, notes, avg_hr, max_hr, effort FROM workouts
            """)
            try db.execute(sql: "DROP TABLE workouts")
            try db.execute(sql: "ALTER TABLE workouts_v4 RENAME TO workouts")
            try db.execute(sql: "CREATE INDEX idx_workouts_date ON workouts(date DESC)")

            // Rest after an interval, in seconds. Nullable: optional, and
            // older intervals have none.
            try db.execute(sql: """
                ALTER TABLE intervals ADD COLUMN rest_seconds REAL
                    CHECK (rest_seconds IS NULL OR rest_seconds >= 0)
            """)
        }
        return m
    }
}
