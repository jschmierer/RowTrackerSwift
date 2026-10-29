import Foundation
import Testing
@testable import RowTracker

@Suite("WorkoutRepository (in-memory)")
struct WorkoutRepositoryTests {
    @Test("save then fetch returns identical workout")
    func saveAndFetch() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)

        let w = Workout(
            kind: .timed,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            notes: "steady state",
            intervals: [
                Interval(durationSec: 900, distanceMeters: 4500),
                Interval(durationSec: 900, distanceMeters: 4600),
            ]
        )
        try repo.save(w)

        let fetched = try #require(try repo.fetchOne(id: w.id))
        #expect(fetched.id == w.id)
        #expect(fetched.kind == .timed)
        #expect(fetched.notes == "steady state")
        #expect(fetched.intervals.count == 2)
        #expect(fetched.intervals.map(\.durationSec) == [900, 900])
        #expect(fetched.intervals.map(\.distanceMeters) == [4500, 4600])
    }

    @Test("nil distance (rest interval) round-trips")
    func nilDistanceRoundTrip() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)
        let w = Workout(kind: .timed, intervals: [
            Interval(durationSec: 30, distanceMeters: nil),
            Interval(durationSec: 30, distanceMeters: nil),
        ])
        try repo.save(w)

        let fetched = try #require(try repo.fetchOne(id: w.id))
        #expect(fetched.intervals.allSatisfy { $0.distanceMeters == nil })
    }

    @Test("save is atomic — a failing interval rolls the whole workout back")
    func writesAreTransactional() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)

        // Build a workout where two intervals share an id. The second insert
        // will fail with a primary-key violation, and the first interval plus
        // the workout header should disappear with it.
        let sharedID = UUID()
        let w = Workout(kind: .timed, intervals: [
            Interval(id: sharedID, durationSec: 60, distanceMeters: 250),
            Interval(id: sharedID, durationSec: 60, distanceMeters: 250),
        ])
        #expect(throws: (any Error).self) { try repo.save(w) }
        #expect(try repo.fetchOne(id: w.id) == nil)
    }

    @Test("all() returns workouts newest first")
    func allOrdersByDateDesc() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)

        let older = Workout(kind: .timed,
                            date: Date(timeIntervalSince1970: 1_600_000_000),
                            intervals: [Interval(durationSec: 600, distanceMeters: 3000)])
        let newer = Workout(kind: .distance,
                            date: Date(timeIntervalSince1970: 1_800_000_000),
                            intervals: [Interval(durationSec: 480, distanceMeters: 2000)])
        try repo.save(older)
        try repo.save(newer)

        let all = try repo.all()
        #expect(all.map(\.id) == [newer.id, older.id])
    }

    @Test("delete removes the workout and its intervals")
    func deleteCascades() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)
        let w = Workout(kind: .timed, intervals: [
            Interval(durationSec: 600, distanceMeters: 3000)
        ])
        try repo.save(w)
        try repo.delete(id: w.id)
        #expect(try repo.count() == 0)
        #expect(try repo.fetchOne(id: w.id) == nil)
    }

    @Test("save with same id replaces intervals")
    func reSaveReplacesIntervals() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)
        var w = Workout(kind: .timed, intervals: [
            Interval(durationSec: 120, distanceMeters: 500),
            Interval(durationSec: 120, distanceMeters: 500),
        ])
        try repo.save(w)
        w.intervals = [Interval(durationSec: 300, distanceMeters: 1500)]
        try repo.save(w)
        let fetched = try #require(try repo.fetchOne(id: w.id))
        #expect(fetched.intervals.count == 1)
        #expect(fetched.intervals[0].durationSec == 300)
    }

    @Test("strokeRate round-trips, including nil")
    func strokeRateRoundTrip() throws {
        let db = try AppDatabase.inMemory()
        let repo = WorkoutRepository(db)
        let w = Workout(kind: .timed, intervals: [
            Interval(durationSec: 300, distanceMeters: 1500, strokeRate: 28),
            Interval(durationSec: 300, distanceMeters: 1500, strokeRate: nil),
            Interval(durationSec: 300, distanceMeters: 1500, strokeRate: 32),
        ])
        try repo.save(w)
        let fetched = try #require(try repo.fetchOne(id: w.id))
        #expect(fetched.intervals.map(\.strokeRate) == [28, nil, 32])
    }
}
