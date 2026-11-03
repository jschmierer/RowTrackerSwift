import Foundation
import GRDB
import Testing
@testable import RowTracker

/// The app on Jakob's phone has real workouts saved under the build-3
/// schema (migrations v1 + v2). Updating the app must keep every one.
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
}
