import Foundation

/// The heading for a workout: "30:00", "2000m", "3x500m", "4x5:00",
/// "1000m/500m/250m". Custom workouts use the title the rower typed.
///
/// Two Time/Distance workouts with the same type and the same title count
/// as "the same workout" for comparisons (see `WorkoutComparison`).
enum WorkoutTitle {
    static func make(for workout: Workout) -> String {
        switch workout.kind {
        case .custom:
            let typed = workout.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return typed.isEmpty ? WorkoutKind.custom.displayName : typed
        case .timed, .distance:
            // The piece the rower set: time for a Time workout, distance
            // for a Distance workout. The other value is the outcome.
            let pieces: [String] = workout.intervals.map { interval in
                workout.kind == .timed
                    ? time(interval.durationSec)
                    : distance(interval.distanceMeters ?? 0)
            }
            guard let first = pieces.first else { return workout.kind.displayName }
            if pieces.count == 1 { return first }
            if pieces.allSatisfy({ $0 == first }) { return "\(pieces.count)x\(first)" }
            return pieces.joined(separator: "/")
        }
    }

    /// Compact time for titles and rest: "30:00", "5:00", "0:45",
    /// "1:00:00". Tenths only when there are some ("1:30.5").
    static func time(_ seconds: TimeInterval) -> String {
        let tenths = Int((max(seconds, 0) * 10).rounded())
        let whole = tenths / 10
        let h = whole / 3600
        let m = (whole % 3600) / 60
        let s = whole % 60
        let frac = tenths % 10
        let sec = frac == 0 ? String(format: "%02d", s) : String(format: "%02d.%d", s, frac)
        return h > 0 ? String(format: "%d:%02d:", h, m) + sec : "\(m):" + sec
    }

    /// "2000m", or "1234.5m" when not a whole number of meters.
    static func distance(_ meters: Double) -> String {
        let rounded = (meters * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))m"
            : String(format: "%.1fm", rounded)
    }
}
