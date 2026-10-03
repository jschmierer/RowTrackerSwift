import Foundation

/// Realistic sample workouts for first-launch seeding. Dates are relative to
/// `now`, so the Progress tab shows something interesting out of the box.
enum SampleData {
    static func seedWorkouts(now: Date = Date()) -> [Workout] {
        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: now) ?? now
        }

        // Each tuple: daysAgo, kind, intervals [(timeStr, meters)], notes
        let plan: [(Int, WorkoutKind, [(String, Double)], String)] = [
            (42, .timed,    [("20:00", 5000)], "steady state"),
            (40, .distance, [("8:12", 2000)], "2k test"),
            (38, .timed,    [("5:00", 1480), ("5:00", 1500), ("5:00", 1510)], "3x5' @ race pace"),
            (35, .distance, [("18:30", 5000)], "long row"),
            (33, .timed,    [("4:00", 1180), ("4:00", 1200), ("4:00", 1215), ("4:00", 1230)], "4x4' build"),
            (30, .distance, [("30:00", 7900)], "steady state, low rate"),
            (27, .distance, [("8:00", 2010)], "2k retest"),
            (24, .timed,    [("1:00", 300), ("1:00", 305), ("1:00", 310), ("1:00", 310), ("1:00", 315)], "5x1'"),
            (21, .timed,    [("20:00", 5200)], "steady state"),
            (17, .distance, [("7:55", 2000)], "2k — PR!"),
            (14, .timed,    [("5:00", 1495), ("5:00", 1500), ("5:00", 1510), ("5:00", 1515)], "4x5' @ 2k+6"),
            (11, .distance, [("35:00", 9200)], "long steady"),
            (7,  .timed,    [("8:00", 2400), ("8:00", 2410), ("8:00", 2420)], "3x8' @ 5k pace"),
            (4,  .distance, [("7:48", 2000)], "2k retest — new PR!"),
            (1,  .timed,    [("30:00", 7700)], "steady state, legs feel strong"),
        ]

        return plan.map { daysBack, kind, pieces, notes in
            let intervals = pieces.map { timeStr, meters in
                let seconds = (try? RowingMath.parseTime(timeStr)) ?? 0
                return Interval(durationSec: seconds, distanceMeters: meters)
            }
            return Workout(
                kind: kind,
                date: daysAgo(daysBack),
                notes: notes,
                intervals: intervals
            )
        }
    }
}
