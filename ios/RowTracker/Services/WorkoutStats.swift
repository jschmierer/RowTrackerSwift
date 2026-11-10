import Foundation

/// Totals and records shown on the Dashboard and Progress tabs. Pure so it
/// can be unit tested.
///
/// Custom workouts count as workouts but have no intervals, so they add no
/// meters, never set a 2k record, and never appear in a weekly-meters bar
/// on their own.
enum WorkoutStats {
    static func totalMeters(_ workouts: [Workout]) -> Double {
        workouts.map(\.totalDistance).reduce(0, +)
    }

    /// Meters since the start of the current week (in `calendar`).
    static func thisWeekMeters(_ workouts: [Workout],
                               now: Date = Date(),
                               calendar: Calendar = .current) -> Double {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return totalMeters(workouts.filter { $0.date >= start })
    }

    /// Fastest time for a single-piece row of about 2000 m (1950–2050 m).
    static func bestTwoK(_ workouts: [Workout]) -> TimeInterval? {
        workouts
            .filter { w in
                w.kind != .custom
                    && w.intervals.count == 1
                    && (1950...2050).contains(w.intervals[0].distanceMeters ?? 0)
            }
            .map(\.totalDuration)
            .min()
    }

    /// Meters per week, oldest week first. Weeks with only Custom workouts
    /// (no meters) are left out rather than drawn as empty bars.
    static func weeklyMeters(_ workouts: [Workout],
                             calendar: Calendar = .current) -> [(weekStart: Date, meters: Double)] {
        var buckets: [Date: Double] = [:]
        for w in workouts where w.kind != .custom {
            let week = calendar.dateInterval(of: .weekOfYear, for: w.date)?.start ?? w.date
            buckets[week, default: 0] += w.totalDistance
        }
        return buckets
            .map { (weekStart: $0.key, meters: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }
}

extension WorkoutKind {
    /// Name shown in the UI ("Time", "Distance", "Custom").
    var displayName: String {
        switch self {
        case .timed: return "Time"
        case .distance: return "Distance"
        case .custom: return "Custom"
        }
    }
}
