import Foundation

/// Display strings for the workout detail screen and the share summary. A
/// missing value (older workouts, or a field the rower left blank) shows as
/// a dash.
enum DetailFormat {
    static let missing = "—"

    static func heartRate(_ bpm: Int?) -> String {
        bpm.map { "\($0) bpm" } ?? missing
    }

    static func effort(_ effort: Int?) -> String {
        effort.map { "\($0) / 10" } ?? missing
    }

    static func watts(_ watts: Double?) -> String {
        watts.map { "\(Int($0.rounded())) W" } ?? missing
    }

    /// "5:00.0", "0:45.0", "1:02:03.4": always tenths, no leading zero.
    static func time(_ seconds: TimeInterval) -> String {
        let s = RowingMath.formatTime(seconds)
        // formatTime pads minutes ("05:00.0") when there are no hours.
        if s.count == 7, s.hasPrefix("0") { return String(s.dropFirst()) }
        return s
    }

    /// "1:45.2 /500m", or a dash.
    static func split(_ split: TimeInterval?) -> String {
        split.map { time($0) + " /500m" } ?? missing
    }

    /// "1500 m", or "12.3 km" from 10 km up.
    static func distance(_ meters: Double?) -> String {
        guard let meters else { return missing }
        if meters >= 10000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    /// "1:00" for rest between intervals.
    static func rest(_ seconds: TimeInterval?) -> String {
        seconds.map(WorkoutTitle.time) ?? missing
    }

    static func strokeRate(_ spm: Int?) -> String {
        spm.map { "\($0) spm" } ?? missing
    }
}
