import Foundation

/// Display strings for the workout detail screen. A missing value (older
/// workouts, or a field the rower left blank) shows as a dash.
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
}
