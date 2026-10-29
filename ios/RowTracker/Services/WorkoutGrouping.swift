import Foundation

/// Groups workouts into comparable sets so a split-over-time chart compares
/// like with like (all 2k pieces together, all 20-minute pieces together),
/// instead of mixing a 20-minute steady state with a 4×5' race-pace set.
///
/// Group identity = (kind, bucketed total). Totals are bucketed to swallow
/// small rounding differences (a 1,980 m workout and a 2,015 m workout both
/// fall into the "2000 m" bucket).
enum WorkoutGrouping {
    /// Distance workouts are bucketed to the nearest 100 m.
    static let distanceBucketMeters: Double = 100
    /// Timed workouts are bucketed to the nearest 60 s.
    static let timeBucketSeconds: Double = 60

    /// Returns the group key for a single workout, or nil if the workout has
    /// no scored intervals (nothing to plot a split for).
    static func groupKey(for workout: Workout) -> WorkoutGroupKey? {
        guard !workout.scoredIntervals.isEmpty else { return nil }
        switch workout.kind {
        case .distance:
            let total = workout.totalDistance
            guard total > 0 else { return nil }
            let bucket = Int((total / distanceBucketMeters).rounded()) * Int(distanceBucketMeters)
            return WorkoutGroupKey(kind: .distance, bucketedTotal: bucket)
        case .timed:
            let total = workout.totalDuration
            guard total > 0 else { return nil }
            let bucket = Int((total / timeBucketSeconds).rounded()) * Int(timeBucketSeconds)
            return WorkoutGroupKey(kind: .timed, bucketedTotal: bucket)
        }
    }

    /// All groups found in the given workouts, sorted by count descending so
    /// the first entry is the "most-popular" group (a sensible default for a
    /// chart's picker). Workouts within each group are sorted by date asc.
    static func groups(from workouts: [Workout]) -> [WorkoutGroup] {
        var buckets: [WorkoutGroupKey: [Workout]] = [:]
        for w in workouts {
            guard let key = groupKey(for: w) else { continue }
            buckets[key, default: []].append(w)
        }
        return buckets
            .map { key, workouts in
                WorkoutGroup(key: key, workouts: workouts.sorted { $0.date < $1.date })
            }
            .sorted { lhs, rhs in
                if lhs.workouts.count != rhs.workouts.count {
                    return lhs.workouts.count > rhs.workouts.count
                }
                // Tie-break: shorter total first (stable, readable order).
                return lhs.key.bucketedTotal < rhs.key.bucketedTotal
            }
    }
}

/// A comparable group of workouts: same type, same bucketed total.
struct WorkoutGroupKey: Hashable, Identifiable {
    let kind: WorkoutKind
    /// Meters for `.distance` workouts, seconds for `.timed` workouts.
    let bucketedTotal: Int

    var id: Self { self }

    /// Short label suitable for a picker row: "2000 m", "20:00", "1:00:00".
    var label: String {
        switch kind {
        case .distance:
            if bucketedTotal >= 10000 {
                return String(format: "%.1f km", Double(bucketedTotal) / 1000)
            }
            return "\(bucketedTotal) m"
        case .timed:
            let totalMinutes = bucketedTotal / 60
            if totalMinutes >= 60 {
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                return String(format: "%d:%02d:00", hours, minutes)
            }
            return String(format: "%d:00", totalMinutes)
        }
    }
}

struct WorkoutGroup: Identifiable {
    let key: WorkoutGroupKey
    let workouts: [Workout]
    var id: WorkoutGroupKey { key }
}
