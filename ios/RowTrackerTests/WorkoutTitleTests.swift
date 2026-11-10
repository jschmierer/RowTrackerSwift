import Foundation
import Testing
@testable import RowTracker

@Suite("WorkoutTitle")
struct WorkoutTitleTests {
    private func timed(_ seconds: [TimeInterval]) -> Workout {
        Workout(kind: .timed, intervals: seconds.map {
            Interval(durationSec: $0, distanceMeters: $0 * 4.2)
        })
    }

    private func distance(_ meters: [Double]) -> Workout {
        Workout(kind: .distance, intervals: meters.map {
            Interval(durationSec: $0 / 4.9, distanceMeters: $0)
        })
    }

    @Test("single Time piece", arguments: [
        (1800.0, "30:00"), (300, "5:00"), (45, "0:45"), (3600, "1:00:00"), (5400, "1:30:00"),
    ])
    func singleTime(seconds: TimeInterval, expected: String) {
        #expect(WorkoutTitle.make(for: timed([seconds])) == expected)
    }

    @Test("single Distance piece")
    func singleDistance() {
        #expect(WorkoutTitle.make(for: distance([2000])) == "2000m")
        #expect(WorkoutTitle.make(for: distance([10000])) == "10000m")
    }

    @Test("equal intervals use NxPiece")
    func equalIntervals() {
        #expect(WorkoutTitle.make(for: distance([500, 500, 500])) == "3x500m")
        #expect(WorkoutTitle.make(for: timed([300, 300, 300, 300])) == "4x5:00")
        #expect(WorkoutTitle.make(for: timed([60, 60])) == "2x1:00")
    }

    @Test("variable intervals list every piece")
    func variableIntervals() {
        #expect(WorkoutTitle.make(for: distance([1000, 500, 250])) == "1000m/500m/250m")
        #expect(WorkoutTitle.make(for: timed([300, 240, 180])) == "5:00/4:00/3:00")
        #expect(WorkoutTitle.make(for: distance([500, 500, 250])) == "500m/500m/250m")
    }

    @Test("the title uses the set value, not the outcome")
    func usesSetValue() {
        // A 30:00 piece covers some distance; its title is still the time.
        let w = Workout(kind: .timed, intervals: [Interval(durationSec: 1800, distanceMeters: 7612)])
        #expect(WorkoutTitle.make(for: w) == "30:00")
        // A 2000m piece takes some time; its title is still the distance.
        let d = Workout(kind: .distance, intervals: [Interval(durationSec: 452.3, distanceMeters: 2000)])
        #expect(WorkoutTitle.make(for: d) == "2000m")
    }

    @Test("rest doesn't change the title")
    func restIgnored() {
        var w = distance([500, 500, 500])
        w.intervals[0].restSec = 60
        w.intervals[1].restSec = 120
        #expect(WorkoutTitle.make(for: w) == "3x500m")
    }

    @Test("custom workouts use the entered title")
    func custom() {
        #expect(WorkoutTitle.make(for: Workout(kind: .custom, title: "Bike 30 min")) == "Bike 30 min")
        #expect(WorkoutTitle.make(for: Workout(kind: .custom, title: "  Weights \n")) == "Weights")
        #expect(WorkoutTitle.make(for: Workout(kind: .custom)) == "Custom")
    }

    @Test("compact time and distance formatting")
    func formatting() {
        #expect(WorkoutTitle.time(90.5) == "1:30.5")
        #expect(WorkoutTitle.time(59.96) == "1:00")
        #expect(WorkoutTitle.time(0) == "0:00")
        #expect(WorkoutTitle.distance(1234.5) == "1234.5m")
        #expect(WorkoutTitle.distance(1999.98) == "2000m")
    }
}
