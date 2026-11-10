import Foundation
import Testing
@testable import RowTracker

@Suite("WorkoutStats (Dashboard and Progress) with Custom workouts")
struct WorkoutStatsTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private var rowed: [Workout] {
        [
            Workout(kind: .distance, date: day(2026, 11, 2),
                    intervals: [Interval(durationSec: 470, distanceMeters: 2000)]),
            Workout(kind: .timed, date: day(2026, 11, 4),
                    intervals: [Interval(durationSec: 1800, distanceMeters: 7500)]),
        ]
    }

    private var custom: Workout {
        Workout(kind: .custom, date: day(2026, 11, 5), title: "Bike 30 min", details: "Zone 2")
    }

    @Test("a Custom workout adds no meters")
    func customAddsNoMeters() {
        #expect(WorkoutStats.totalMeters(rowed) == 9500)
        #expect(WorkoutStats.totalMeters(rowed + [custom]) == 9500)
        let now = day(2026, 11, 6)
        #expect(WorkoutStats.thisWeekMeters(rowed + [custom], now: now, calendar: calendar)
                == WorkoutStats.thisWeekMeters(rowed, now: now, calendar: calendar))
    }

    @Test("a Custom workout never sets a 2k record")
    func customNeverBest2k() {
        #expect(WorkoutStats.bestTwoK(rowed + [custom]) == 470)
        #expect(WorkoutStats.bestTwoK([custom]) == nil)
    }

    @Test("a week with only Custom workouts has no meters bar")
    func customOnlyWeekSkipped() {
        let lone = Workout(kind: .custom, date: day(2026, 10, 1), title: "Run")
        let weeks = WorkoutStats.weeklyMeters(rowed + [lone], calendar: calendar)
        #expect(weeks.count == 1)
        #expect(weeks[0].meters == 9500)
    }

    @Test("a Custom workout is never in a split chart group")
    func customNotGrouped() {
        #expect(WorkoutGrouping.groupKey(for: custom) == nil)
        let groups = WorkoutGrouping.groups(from: rowed + [custom])
        #expect(groups.flatMap(\.workouts).allSatisfy { $0.kind != .custom })
        #expect(custom.averageSplit == nil)
    }
}
