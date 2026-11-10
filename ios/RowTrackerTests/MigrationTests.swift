import Foundation
import GRDB
import Testing
@testable import RowTracker

/// The app on Jakob's phone has real workouts saved under older schemas
/// (build 3: v1 + v2; build 5: v1–v3). Updating the app must keep every one.
@Suite("Database migrations")
struct MigrationTests {
    /// A fresh on-disk database file, like the one in Application Support.
    private func makeQueue() throws -> (DatabaseQueue, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rowtracker-migration-\(UUID().uuidString).sqlite")
        var config = Configuration()
        config.foreignKeysEnabled = true
        return (try DatabaseQueue(path: url.path, configuration: config), url)
    }

    /// Inserts workouts with raw SQL using only the columns that existed
    /// when the database was created.
    private func seedOldRows(_ queue: DatabaseQueue, withStrokeRate: Bool) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO workouts (id, kind, date, notes) VALUES
                    ('11111111-1111-1111-1111-111111111111', 'timed',    1700000000, 'steady 20'),
                    ('22222222-2222-2222-2222-222222222222', 'distance', 1700500000, '')
            """)
            if withStrokeRate {
                try db.execute(sql: """
                    INSERT INTO intervals
                        (id, workout_id, position, duration_sec, distance_meters, stroke_rate)
                    VALUES
                        ('AAAAAAAA-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 0, 600, 2600, 22),
                        ('AAAAAAAA-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1, 600, 2650, NULL),
                        ('AAAAAAAA-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 0, 452.5, 2000, 30)
                """)
            } else {
                try db.execute(sql: """
                    INSERT INTO intervals
                        (id, workout_id, position, duration_sec, distance_meters)
                    VALUES
                        ('AAAAAAAA-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 0, 600, 2600),
                        ('AAAAAAAA-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1, 600, 2650),
                        ('AAAAAAAA-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 0, 452.5, 2000)
                """)
            }
        }
    }

    @Test("upgrading a build-3 database (v1+v2) keeps workouts and intervals")
    func upgradeFromV2() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }

        // 1. The database as build 3 left it.
        try AppDatabase.migrator.migrate(queue, upTo: "v2_add_stroke_rate")
        try seedOldRows(queue, withStrokeRate: true)

        // 2. Open it with the current app, which applies the new migrations.
        let repo = WorkoutRepository(try AppDatabase(queue))

        let applied = try queue.read { try AppDatabase.migrator.appliedIdentifiers($0) }
        #expect(applied.contains("v3_add_heart_rate_and_effort"))

        let all = try repo.all()
        #expect(all.count == 2)

        let timed = try #require(all.first { $0.kind == .timed })
        #expect(timed.notes == "steady 20")
        #expect(timed.date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(timed.intervals.map(\.durationSec) == [600, 600])
        #expect(timed.intervals.map(\.distanceMeters) == [2600, 2650])
        #expect(timed.intervals.map(\.strokeRate) == [22, nil])

        let distance = try #require(all.first { $0.kind == .distance })
        #expect(distance.intervals.count == 1)
        #expect(distance.intervals[0].durationSec == 452.5)
        #expect(distance.intervals[0].strokeRate == 30)

        // Old workouts have no heart rate or effort.
        for w in all {
            #expect(w.avgHR == nil)
            #expect(w.maxHR == nil)
            #expect(w.effort == nil)
        }
    }

    @Test("upgrading a v1-only database keeps workouts and intervals")
    func upgradeFromV1() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }

        try AppDatabase.migrator.migrate(queue, upTo: "v1_schema")
        try seedOldRows(queue, withStrokeRate: false)

        let repo = WorkoutRepository(try AppDatabase(queue))
        let all = try repo.all()
        #expect(all.count == 2)
        #expect(all.flatMap(\.intervals).count == 3)
        #expect(all.flatMap(\.intervals).allSatisfy { $0.strokeRate == nil })
    }

    @Test("an upgraded old workout can be re-saved with the new fields")
    func oldWorkoutResave() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }

        try AppDatabase.migrator.migrate(queue, upTo: "v2_add_stroke_rate")
        try seedOldRows(queue, withStrokeRate: true)
        let repo = WorkoutRepository(try AppDatabase(queue))

        var w = try #require(try repo.all().first { $0.kind == .timed })
        w.avgHR = 150
        w.maxHR = 172
        w.effort = 7
        try repo.save(w)

        let fetched = try #require(try repo.fetchOne(id: w.id))
        #expect(fetched.avgHR == 150)
        #expect(fetched.maxHR == 172)
        #expect(fetched.effort == 7)
        #expect(fetched.intervals.count == 2)
    }

    @Test("opening an already-migrated database again is a no-op")
    func reopenIsIdempotent() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }
        let repo = WorkoutRepository(try AppDatabase(queue))
        try repo.save(Workout(kind: .timed, intervals: [Interval(durationSec: 60, distanceMeters: 250)],
                              avgHR: 140, maxHR: 160, effort: 4))
        let reopened = WorkoutRepository(try AppDatabase(queue))
        #expect(try reopened.count() == 1)
    }

    // MARK: - Build 5 (v1–v3) to v4: custom workouts, titles, rest

    /// Seeds a database the way build 5 left it (migrations v1–v3) with
    /// raw SQL that uses only the columns that existed then.
    private func seedBuild5Rows(_ queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO workouts (id, kind, date, notes, avg_hr, max_hr, effort) VALUES
                    ('11111111-1111-1111-1111-111111111111', 'timed',    1700000000, 'steady 20', 150, 171, 6),
                    ('22222222-2222-2222-2222-222222222222', 'distance', 1700500000, '',          NULL, NULL, NULL),
                    ('33333333-3333-3333-3333-333333333333', 'distance', 1701000000, '3x500m',    162, 185, 9)
            """)
            try db.execute(sql: """
                INSERT INTO intervals
                    (id, workout_id, position, duration_sec, distance_meters, stroke_rate)
                VALUES
                    ('AAAAAAAA-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 0, 600, 2600, 22),
                    ('AAAAAAAA-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1, 600, 2650, NULL),
                    ('AAAAAAAA-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 0, 452.5, 2000, 30),
                    ('AAAAAAAA-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 0, 95.2, 500, 32),
                    ('AAAAAAAA-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 1, 96.0, 500, 31),
                    ('AAAAAAAA-0000-0000-0000-000000000006', '33333333-3333-3333-3333-333333333333', 2, 94.8, 500, NULL)
            """)
        }
    }

    /// Every column of every row that existed before v4, in a fixed order.
    private func dumpOldColumns(_ queue: DatabaseQueue) throws -> (workouts: [Row], intervals: [Row]) {
        try queue.read { db in
            let w = try Row.fetchAll(db, sql: """
                SELECT id, kind, date, notes, avg_hr, max_hr, effort FROM workouts ORDER BY id
            """)
            let i = try Row.fetchAll(db, sql: """
                SELECT id, workout_id, position, duration_sec, distance_meters, stroke_rate
                FROM intervals ORDER BY id
            """)
            return (w, i)
        }
    }

    @Test("upgrading a build-5 database (v1–v3) to v4 keeps every row unchanged")
    func upgradeFromV3() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }

        // 1. The database exactly as build 5 left it.
        try AppDatabase.migrator.migrate(queue, upTo: "v3_add_heart_rate_and_effort")
        try seedBuild5Rows(queue)
        let before = try dumpOldColumns(queue)
        #expect(before.workouts.count == 3)
        #expect(before.intervals.count == 6)

        // 2. Open it with the current app, which applies v4.
        let repo = WorkoutRepository(try AppDatabase(queue))
        let applied = try queue.read { try AppDatabase.migrator.appliedIdentifiers($0) }
        #expect(applied.contains("v4_custom_workouts_and_rest"))

        // 3. Every row and every old column survives exactly. (Rebuilding
        //    `workouts` must not cascade-delete intervals.)
        let after = try dumpOldColumns(queue)
        #expect(after.workouts == before.workouts)
        #expect(after.intervals == before.intervals)
        let fkProblems = try queue.read { try Row.fetchAll($0, sql: "PRAGMA foreign_key_check") }
        #expect(fkProblems.isEmpty)

        // 4. New columns are empty on old rows.
        let all = try repo.all()
        #expect(all.count == 3)
        #expect(all.flatMap(\.intervals).count == 6)
        for w in all {
            #expect(w.title == nil)
            #expect(w.details == nil)
            #expect(w.intervals.allSatisfy { $0.restSec == nil })
        }
        let timed = try #require(all.first { $0.kind == .timed })
        #expect(timed.avgHR == 150)
        #expect(timed.maxHR == 171)
        #expect(timed.effort == 6)
        #expect(timed.intervals.map(\.strokeRate) == [22, nil])
    }

    @Test("after v4: custom workouts and rest save, constraints and cascade still work")
    func v4SchemaBehaves() throws {
        let (queue, url) = try makeQueue()
        defer { try? FileManager.default.removeItem(at: url) }
        try AppDatabase.migrator.migrate(queue, upTo: "v3_add_heart_rate_and_effort")
        try seedBuild5Rows(queue)
        let repo = WorkoutRepository(try AppDatabase(queue))

        // Custom workouts are allowed now.
        let custom = Workout(kind: .custom, notes: "legs", title: "Bike 30 min",
                             details: "Zone 2\nCadence 90")
        try repo.save(custom)
        let fetched = try #require(try repo.fetchOne(id: custom.id))
        #expect(fetched.kind == .custom)
        #expect(fetched.title == "Bike 30 min")
        #expect(fetched.details == "Zone 2\nCadence 90")
        #expect(fetched.intervals.isEmpty)

        // Rest round-trips on an old workout that gets re-saved.
        var old = try #require(try repo.all().first { $0.intervals.count == 3 })
        old.intervals[0].restSec = 60
        old.intervals[1].restSec = 90
        try repo.save(old)
        let reloaded = try #require(try repo.fetchOne(id: old.id))
        #expect(reloaded.intervals.map(\.restSec) == [60, 90, nil])

        // CHECK constraints survived the rebuild.
        #expect(throws: (any Error).self) {
            try queue.write { db in
                try db.execute(sql: """
                    INSERT INTO workouts (id, kind, date) VALUES ('bad', 'rowing', 0)
                """)
            }
        }
        #expect(throws: (any Error).self) {
            try queue.write { db in
                try db.execute(sql: """
                    INSERT INTO workouts (id, kind, date, avg_hr) VALUES ('bad2', 'timed', 0, 500)
                """)
            }
        }
        #expect(throws: (any Error).self) {
            try queue.write { db in
                try db.execute(sql: "UPDATE intervals SET rest_seconds = -1")
            }
        }

        // The intervals -> workouts foreign key still cascades on delete.
        try repo.delete(id: old.id)
        let orphans = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM intervals WHERE workout_id = ?",
                             arguments: [old.id.uuidString]) ?? -1
        }
        #expect(orphans == 0)
    }
}
