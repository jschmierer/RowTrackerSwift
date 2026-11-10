import Foundation
import Testing
@testable import RowTracker

@Suite("Overall averages")
struct AverageRateTests {
    @Test("average rate is weighted by interval duration")
    func durationWeighted() throws {
        // 10:00 at 20 and 1:00 at 31 -> (20 x 600 + 31 x 60) / 660 = 21.0
        let intervals = [
            Interval(durationSec: 600, distanceMeters: 2500, strokeRate: 20),
            Interval(durationSec: 60, distanceMeters: 300, strokeRate: 31),
        ]
        let rate = try #require(WorkoutStats.averageStrokeRate(intervals))
        #expect(abs(rate - 21.0) < 1e-9)
        // A plain mean would be 25.5.
        #expect(rate != 25.5)
    }

    @Test("intervals without a rate are left out of the average")
    func skipsMissing() {
        let intervals = [
            Interval(durationSec: 300, distanceMeters: 1400, strokeRate: 24),
            Interval(durationSec: 300, distanceMeters: 1400, strokeRate: nil),
            Interval(durationSec: 100, distanceMeters: 450, strokeRate: 32),
        ]
        // (24*300 + 32*100) / 400 = 26
        #expect(WorkoutStats.averageStrokeRate(intervals) == 26)
    }

    @Test("no rates means no average")
    func noneRated() {
        #expect(WorkoutStats.averageStrokeRate([]) == nil)
        #expect(WorkoutStats.averageStrokeRate([Interval(durationSec: 60, distanceMeters: 250)]) == nil)
        #expect(Workout(kind: .custom, title: "Run").averageStrokeRate == nil)
    }

    @Test("rest doesn't affect the average rate")
    func restIgnored() {
        let a = [Interval(durationSec: 100, distanceMeters: 500, strokeRate: 30, restSec: 600),
                 Interval(durationSec: 100, distanceMeters: 500, strokeRate: 20)]
        #expect(WorkoutStats.averageStrokeRate(a) == 25)
    }

    @Test("average split is total time / total distance x 500; watts come from it")
    func averageSplitAndWatts() throws {
        let w = Workout(kind: .distance, intervals: [
            Interval(durationSec: 90, distanceMeters: 500),
            Interval(durationSec: 110, distanceMeters: 500),
        ])
        #expect(w.averageSplit == 100)
        // From the 1:40.0 average split, not the mean of each interval's watts.
        #expect(PaceMode.watts.format(split: w.averageSplit) == "350 W")
        let meanOfWatts = w.intervals.compactMap(\.watts).reduce(0, +) / 2
        #expect(Int(meanOfWatts.rounded()) != 350)
    }

    @Test("average rate display")
    func display() {
        #expect(DetailFormat.averageRate(28) == "28 spm")
        #expect(DetailFormat.averageRate(28.46) == "28.5 spm")
        #expect(DetailFormat.averageRate(nil) == "—")
    }
}
