import Foundation
import GRDB

/// All SQL for persisting workouts lives here. The rest of the app sees only
/// `Workout` values. Writes are transactional so a workout and its intervals
/// land together.
struct WorkoutRepository {
    let db: AppDatabase

    init(_ db: AppDatabase) {
        self.db = db
    }

    // MARK: - Writes

    func save(_ workout: Workout) throws {
        try db.writer.write { d in
            try d.execute(
                sql: """
                INSERT OR REPLACE INTO workouts (id, kind, date, notes)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [
                    workout.id.uuidString,
                    workout.kind.rawValue,
                    workout.date.timeIntervalSince1970,
                    workout.notes,
                ]
            )
            // Replace existing intervals so a re-save stays consistent.
            try d.execute(
                sql: "DELETE FROM intervals WHERE workout_id = ?",
                arguments: [workout.id.uuidString]
            )
            for (position, interval) in workout.intervals.enumerated() {
                try d.execute(
                    sql: """
                    INSERT INTO intervals
                        (id, workout_id, position, duration_sec, distance_meters)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: StatementArguments([
                        interval.id.uuidString,
                        workout.id.uuidString,
                        position,
                        interval.durationSec,
                        interval.distanceMeters,
                    ] as [(any DatabaseValueConvertible)?])
                )
            }
        }
    }

    func delete(id: UUID) throws {
        _ = try db.writer.write { d in
            try d.execute(
                sql: "DELETE FROM workouts WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    func deleteAll() throws {
        try db.writer.write { d in
            try d.execute(sql: "DELETE FROM workouts")
        }
    }

    // MARK: - Reads

    func all() throws -> [Workout] {
        try db.writer.read { d in try Self.loadAll(from: d) }
    }

    func fetchOne(id: UUID) throws -> Workout? {
        try db.writer.read { d in
            guard let header = try Self.fetchHeader(d, id: id.uuidString) else { return nil }
            let intervals = try Self.fetchIntervals(d, workoutId: id.uuidString)
            return Self.workout(from: header, intervals: intervals)
        }
    }

    func count() throws -> Int {
        try db.writer.read { d in
            try Int.fetchOne(d, sql: "SELECT COUNT(*) FROM workouts") ?? 0
        }
    }

    // MARK: - SQL helpers

    private struct Header {
        let id: String
        let kind: String
        let date: Double
        let notes: String
    }

    private static func loadAll(from d: Database) throws -> [Workout] {
        let headers = try Row
            .fetchAll(d, sql: """
                SELECT id, kind, date, notes
                FROM workouts
                ORDER BY date DESC
            """)
            .map {
                Header(id: $0["id"], kind: $0["kind"], date: $0["date"], notes: $0["notes"])
            }

        // One query for all intervals, then bucket by workout_id — cheaper than
        // N+1 trips for larger libraries.
        let intervalRows = try Row.fetchAll(d, sql: """
            SELECT id, workout_id, position, duration_sec, distance_meters
            FROM intervals
            ORDER BY workout_id, position
        """)
        var bucketed: [String: [Interval]] = [:]
        for row in intervalRows {
            let interval = interval(from: row)
            bucketed[row["workout_id"], default: []].append(interval)
        }

        return headers.map { workout(from: $0, intervals: bucketed[$0.id] ?? []) }
    }

    private static func fetchHeader(_ d: Database, id: String) throws -> Header? {
        guard let row = try Row.fetchOne(
            d,
            sql: "SELECT id, kind, date, notes FROM workouts WHERE id = ?",
            arguments: [id]
        ) else { return nil }
        return Header(id: row["id"], kind: row["kind"], date: row["date"], notes: row["notes"])
    }

    private static func fetchIntervals(_ d: Database, workoutId: String) throws -> [Interval] {
        try Row.fetchAll(
            d,
            sql: """
                SELECT id, position, duration_sec, distance_meters
                FROM intervals
                WHERE workout_id = ?
                ORDER BY position
            """,
            arguments: [workoutId]
        ).map(interval(from:))
    }

    private static func interval(from row: Row) -> Interval {
        let id = UUID(uuidString: row["id"]) ?? UUID()
        let distance: Double? = row["distance_meters"]
        return Interval(id: id, durationSec: row["duration_sec"], distanceMeters: distance)
    }

    private static func workout(from header: Header, intervals: [Interval]) -> Workout {
        Workout(
            id: UUID(uuidString: header.id) ?? UUID(),
            kind: WorkoutKind(rawValue: header.kind) ?? .timed,
            date: Date(timeIntervalSince1970: header.date),
            notes: header.notes,
            intervals: intervals
        )
    }
}
