import Foundation
import Testing
@testable import RowTracker

@Suite("WorkoutComparison: matching, previous, best")
struct WorkoutComparisonTests {
    private let base = Date(timeIntervalSince1970: 1_790_000_000)

    private func day(_ n: Int) -> Date { base.addingTimeInterval(Double(n) * 86_400) }

    /// A single 2000m piece in `seconds`.
    private func twoK(_ seconds: TimeInterval, day n: Int) -> Workout {
        Workout(kind: .distance, date: day(n),
                intervals: [Interval(durationSec: seconds, distanceMeters: 2000)])
    }

    private func threeBy500(_ seconds: TimeInterval, day n: Int) -> Workout {
        Workout(kind: .distance, date: day(n),
                intervals: (0..<3).map { _ in Interval(durationSec: seconds, distanceMeters: 500) })
    }

    // MARK: Matching

    @Test("same type and same generated title match")
    func matching() {
        #expect(WorkoutComparison.isSameWorkout(twoK(480, day: 0), twoK(470, day: 5)))
        #expect(WorkoutComparison.isSameWorkout(threeBy500(100, day: 0), threeBy500(95, day: 1)))
        // Different shape.
        #expect(!WorkoutComparison.isSameWorkout(twoK(480, day: 0), threeBy500(100, day: 1)))
        let fourBy500 = Workout(kind: .distance, date: day(1), intervals: (0..<4).map { _ in
            Interval(durationSec: 100, distanceMeters: 500)
        })
        #expect(!WorkoutComparison.isSameWorkout(threeBy500(100, day: 0), fourBy500))
        // Variable pieces must be in the same order.
        let a = Workout(kind: .distance, intervals: [Interval(durationSec: 200, distanceMeters: 1000),
                                                     Interval(durationSec: 100, distanceMeters: 500)])
        let b = Workout(kind: .distance, intervals: [Interval(durationSec: 100, distanceMeters: 500),
                                                     Interval(durationSec: 200, distanceMeters: 1000)])
        #expect(!WorkoutComparison.isSameWorkout(a, b))
    }

    @Test("a Time workout never matches a Distance workout")
    func kindMustMatch() {
        // 2000m in 8:00 vs 8:00 that covered 2000m: different workouts.
        let distance = twoK(480, day: 0)
        let timed = Workout(kind: .timed, date: day(1),
                            intervals: [Interval(durationSec: 480, distanceMeters: 2000)])
        #expect(!WorkoutComparison.isSameWorkout(distance, timed))
    }

    @Test("custom workouts never match, even with the same title")
    func customNeverMatches() {
        let a = Workout(kind: .custom, date: day(0), title: "Bike")
        let b = Workout(kind: .custom, date: day(1), title: "Bike")
        #expect(!WorkoutComparison.isSameWorkout(a, b))
        #expect(WorkoutComparison.make(for: b, among: [a, b]) == nil)
        #expect(WorkoutComparison.matches(for: b, among: [a, b]).isEmpty)
    }

    // MARK: Previous

    @Test("previous is the most recent earlier match, ignoring later ones and other shapes")
    func previous() {
        let w1 = twoK(490, day: 0)
        let w2 = twoK(480, day: 10)
        let other = threeBy500(95, day: 15)
        let current = twoK(475, day: 20)
        let later = twoK(470, day: 30)
        let all = [later, current, other, w2, w1]   // newest first, like the store
        #expect(WorkoutComparison.previous(for: current, among: all)?.id == w2.id)
        #expect(WorkoutComparison.previous(for: w2, among: all)?.id == w1.id)
        #expect(WorkoutComparison.previous(for: w1, among: all) == nil)
    }

    @Test("a same-day match is not 'previous'")
    func sameDay() {
        let morning = twoK(480, day: 5)
        let evening = twoK(470, day: 5)
        #expect(WorkoutComparison.previous(for: evening, among: [morning, evening]) == nil)
        #expect(WorkoutComparison.make(for: evening, among: [morning, evening]) == nil)
    }

    @Test("no earlier match hides the comparison")
    func noEarlier() {
        let only = twoK(480, day: 0)
        #expect(WorkoutComparison.make(for: only, among: [only]) == nil)
        #expect(WorkoutComparison.make(for: only, among: []) == nil)
    }

    // MARK: Best

    @Test("best is the fastest earlier average split")
    func best() {
        let slow = twoK(500, day: 0)
        let fastest = twoK(465, day: 5)
        let recent = twoK(480, day: 10)
        let current = twoK(470, day: 20)
        let c = WorkoutComparison.make(for: current, among: [current, recent, fastest, slow])
        #expect(c?.previous.id == recent.id)
        #expect(c?.best?.id == fastest.id)
    }

    @Test("best can be the same workout as previous")
    func bestSameAsPrevious() {
        let old = twoK(500, day: 0)
        let recent = twoK(470, day: 10)
        let current = twoK(480, day: 20)
        let c = WorkoutComparison.make(for: current, among: [current, recent, old])
        #expect(c?.previous.id == recent.id)
        #expect(c?.best?.id == recent.id)
    }

    @Test("best never includes this workout or later ones, even if faster")
    func bestExcludesSelfAndLater() {
        let old = twoK(500, day: 0)
        let current = twoK(450, day: 10)
        let later = twoK(440, day: 20)
        #expect(WorkoutComparison.best(for: current, among: [later, current, old])?.id == old.id)
    }

    @Test("best ties go to the most recent")
    func bestTie() {
        let a = twoK(480, day: 0)
        let b = twoK(480, day: 5)
        let current = twoK(490, day: 10)
        #expect(WorkoutComparison.best(for: current, among: [current, b, a])?.id == b.id)
    }

    @Test("interval workouts compare by overall average split; rest doesn't count")
    func intervalBest() {
        var restful = threeBy500(96, day: 0)       // 1:36 average, lots of rest
        restful.intervals[0].restSec = 600
        restful.intervals[1].restSec = 600
        let quick = threeBy500(98, day: 5)          // 1:38 average, no rest
        let current = threeBy500(97, day: 10)
        #expect(WorkoutComparison.best(for: current, among: [current, quick, restful])?.id == restful.id)
    }

    // MARK: Graph history

    @Test("history is every match including this one, oldest first")
    func history() throws {
        let w1 = twoK(490, day: 0)
        let w2 = twoK(480, day: 10)
        let current = twoK(475, day: 20)
        let later = twoK(470, day: 30)
        let noise = threeBy500(95, day: 15)
        // `current` isn't in the list yet (e.g. a stale snapshot): still included.
        let c = try #require(WorkoutComparison.make(for: current, among: [later, noise, w2, w1]))
        #expect(c.history.map(\.id) == [w1.id, w2.id, current.id, later.id])
    }
}
