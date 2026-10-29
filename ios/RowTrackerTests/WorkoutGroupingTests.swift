import Foundation
import Testing
@testable import RowTracker

private func makeWorkout(kind: WorkoutKind,
                         date: TimeInterval,
                         intervals: [(duration: Double, distance: Double?)]) -> Workout {
    Workout(
        kind: kind,
        date: Date(timeIntervalSince1970: date),
        intervals: intervals.map {
            Interval(durationSec: $0.duration, distanceMeters: $0.distance)
        }
    )
}

@Suite("WorkoutGrouping")
struct WorkoutGroupingTests {
    @Test("Distance workouts bucket to nearest 100 m")
    func distanceBuckets() {
        let a = makeWorkout(kind: .distance, date: 1, intervals: [(400, 2000)])
        let b = makeWorkout(kind: .distance, date: 2, intervals: [(410, 1980)])
        let c = makeWorkout(kind: .distance, date: 3, intervals: [(405, 2049)])
        for w in [a, b, c] {
            let key = WorkoutGrouping.groupKey(for: w)
            #expect(key?.kind == .distance)
            #expect(key?.bucketedTotal == 2000)
            #expect(key?.label == "2000 m")
        }
    }

    @Test("Timed workouts bucket to nearest 60 s")
    func timedBuckets() {
        let a = makeWorkout(kind: .timed, date: 1, intervals: [(1200, 5000)])
        let b = makeWorkout(kind: .timed, date: 2, intervals: [(1195, 4900)])  // 19:55
        let c = makeWorkout(kind: .timed, date: 3, intervals: [(1214, 5100)])  // 20:14
        for w in [a, b, c] {
            let key = WorkoutGrouping.groupKey(for: w)
            #expect(key?.kind == .timed)
            #expect(key?.bucketedTotal == 1200)
            #expect(key?.label == "20:00")
        }
    }

    @Test("Timed label handles hours")
    func timedLabelHours() {
        let w = makeWorkout(kind: .timed, date: 1, intervals: [(3900, 15000)])  // 1:05:00
        let key = WorkoutGrouping.groupKey(for: w)
        #expect(key?.bucketedTotal == 3900)
        #expect(key?.label == "1:05:00")
    }

    @Test("Distance label uses km above 10 km")
    func distanceKmLabel() {
        let w = makeWorkout(kind: .distance, date: 1, intervals: [(2700, 12000)])
        let key = WorkoutGrouping.groupKey(for: w)
        #expect(key?.label == "12.0 km")
    }

    @Test("No scored intervals → nil key")
    func noScoredIntervals() {
        let restOnly = makeWorkout(kind: .timed, date: 1, intervals: [
            (30, nil), (30, nil)
        ])
        #expect(WorkoutGrouping.groupKey(for: restOnly) == nil)
    }

    @Test("groups() sorts by count desc, then shorter total first")
    func groupsSortByCountDesc() {
        let g1a = makeWorkout(kind: .distance, date: 1, intervals: [(400, 2000)])
        let g1b = makeWorkout(kind: .distance, date: 2, intervals: [(410, 2000)])
        let g1c = makeWorkout(kind: .distance, date: 3, intervals: [(420, 2000)])
        let g2a = makeWorkout(kind: .distance, date: 4, intervals: [(1200, 5000)])
        let g2b = makeWorkout(kind: .distance, date: 5, intervals: [(1210, 5000)])
        let g3  = makeWorkout(kind: .timed, date: 6, intervals: [(1200, 5000)])

        let groups = WorkoutGrouping.groups(from: [g1a, g1b, g1c, g2a, g2b, g3])
        #expect(groups.count == 3)
        #expect(groups[0].key.label == "2000 m")
        #expect(groups[0].workouts.count == 3)
        #expect(groups[1].workouts.count == 2)
        #expect(groups[2].workouts.count == 1)
    }

    @Test("Workouts within a group are sorted by date ascending")
    func workoutsSortedByDate() {
        let a = makeWorkout(kind: .distance, date: 300, intervals: [(400, 2000)])
        let b = makeWorkout(kind: .distance, date: 100, intervals: [(410, 2000)])
        let c = makeWorkout(kind: .distance, date: 200, intervals: [(420, 2000)])
        let groups = WorkoutGrouping.groups(from: [a, b, c])
        #expect(groups.count == 1)
        #expect(groups[0].workouts.map(\.date.timeIntervalSince1970) == [100, 200, 300])
    }
}
