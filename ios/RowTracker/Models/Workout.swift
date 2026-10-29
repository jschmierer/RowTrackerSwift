import Foundation

/// A workout is a series of intervals, each with a duration and optionally a
/// distance. Split (per 500 m) is always computed from duration and distance,
/// never stored.
enum WorkoutKind: String, Codable, CaseIterable, Hashable {
    case timed       // "do 15 minutes" — distance is the outcome
    case distance    // "do 2000 m" — time is the outcome
}

struct Interval: Identifiable, Codable, Hashable {
    var id: UUID
    /// Duration in seconds. Always present.
    var durationSec: TimeInterval
    /// Distance in meters. Optional: rest intervals like "10x0:30" have no distance.
    var distanceMeters: Double?
    /// Stroke rate in strokes per minute. Optional — not every workout
    /// records it; the Log form doesn't capture it yet.
    var strokeRate: Int?

    init(id: UUID = UUID(),
         durationSec: TimeInterval,
         distanceMeters: Double? = nil,
         strokeRate: Int? = nil) {
        self.id = id
        self.durationSec = durationSec
        self.distanceMeters = distanceMeters
        self.strokeRate = strokeRate
    }

    /// Split per 500 m, computed. Nil when distance is missing or non-positive.
    var splitSec: TimeInterval? {
        guard let d = distanceMeters, d > 0, durationSec > 0 else { return nil }
        return RowingMath.split(fromTime: durationSec, distance: d)
    }
}

struct Workout: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: WorkoutKind
    var date: Date
    var notes: String
    var intervals: [Interval]

    init(id: UUID = UUID(),
         kind: WorkoutKind,
         date: Date = Date(),
         notes: String = "",
         intervals: [Interval] = []) {
        self.id = id
        self.kind = kind
        self.date = date
        self.notes = notes
        self.intervals = intervals
    }

    /// Intervals that have both a duration and a positive distance.
    /// Only these contribute to totals and the average split.
    var scoredIntervals: [Interval] {
        intervals.filter { ($0.distanceMeters ?? 0) > 0 }
    }

    var totalDuration: TimeInterval {
        scoredIntervals.map(\.durationSec).reduce(0, +)
    }

    var totalDistance: Double {
        scoredIntervals.compactMap(\.distanceMeters).reduce(0, +)
    }

    /// Total duration counting EVERY interval (including rest pieces).
    var elapsedDuration: TimeInterval {
        intervals.map(\.durationSec).reduce(0, +)
    }

    /// Average split per 500 m across scored intervals. Nil when there is no
    /// scored distance.
    var averageSplit: TimeInterval? {
        RowingMath.averageSplit(totalTime: totalDuration, totalDistance: totalDistance)
    }
}
