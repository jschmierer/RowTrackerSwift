import Foundation

/// Compares a Time/Distance workout with earlier rows of the same workout.
///
/// "Same workout" = same type and same generated title (`WorkoutTitle`), so
/// a 2000m compares with other 2000m pieces and 4x5:00 with other 4x5:00
/// sets. Custom workouts never match anything.
///
/// "Earlier" = an earlier day. Workouts are saved by day with no time of
/// day, so two of the same workout on one day aren't each other's previous.
struct WorkoutComparison {
    /// The most recent earlier matching workout.
    let previous: Workout
    /// The earlier matching workout with the fastest average split (it may
    /// be the same workout as `previous`). Nil only if no earlier match has
    /// a split.
    let best: Workout?
    /// Every matching workout, this one included, oldest first: the graph.
    let history: [Workout]

    /// Nil for Custom workouts and when there's no earlier matching workout,
    /// which hides the comparison.
    static func make(for workout: Workout, among all: [Workout]) -> WorkoutComparison? {
        guard let previous = previous(for: workout, among: all) else { return nil }
        return WorkoutComparison(previous: previous,
                                 best: best(for: workout, among: all),
                                 history: matches(for: workout, among: all))
    }

    static func isSameWorkout(_ a: Workout, _ b: Workout) -> Bool {
        a.kind != .custom
            && a.kind == b.kind
            && WorkoutTitle.make(for: a) == WorkoutTitle.make(for: b)
    }

    /// Every workout matching `workout`, including itself (whether or not
    /// it's in `all`), oldest first.
    static func matches(for workout: Workout, among all: [Workout]) -> [Workout] {
        guard workout.kind != .custom else { return [] }
        let others = all.filter { $0.id != workout.id && isSameWorkout($0, workout) }
        return (others + [workout]).sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Matching workouts from days before this one.
    static func earlier(than workout: Workout, among all: [Workout]) -> [Workout] {
        matches(for: workout, among: all).filter { $0.id != workout.id && $0.date < workout.date }
    }

    static func previous(for workout: Workout, among all: [Workout]) -> Workout? {
        earlier(than: workout, among: all).last
    }

    /// Fastest average split among earlier matches; on a tie, the most
    /// recent one.
    static func best(for workout: Workout, among all: [Workout]) -> Workout? {
        var best: (workout: Workout, split: TimeInterval)?
        for candidate in earlier(than: workout, among: all) {   // oldest first
            guard let split = candidate.averageSplit else { continue }
            if best == nil || split <= best!.split { best = (candidate, split) }
        }
        return best?.workout
    }
}
