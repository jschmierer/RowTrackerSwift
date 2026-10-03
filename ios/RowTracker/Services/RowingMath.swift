import Foundation

/// Pure math and string formatting for rowing times, splits, and distances.
///
/// This replaces the Python `Workout.timeFormat` and `Workout.calcAverage`
/// helpers. Names map as follows:
///   - `timeFormat(s, True)`  -> `parseTime(_:)`
///   - `timeFormat(sec, False)` -> `formatTime(_:)`
///   - `calcAverage` -> `averageSplit(totalTime:totalDistance:)`
///
/// Behavior deliberately differs from Python where the Python result was buggy
/// (see tests/vectors/*.json with "suspected_bug": true).
enum RowingMath {
    /// The split distance used throughout rowing: 500 meters.
    static let splitDistance: Double = 500

    enum ParseError: LocalizedError, Equatable {
        case empty
        case badFormat(String)
        case fieldOutOfRange(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Enter a time like 1:40 or 5:00."
            case .badFormat(let raw):
                return "\"\(raw)\" isn't a time. Try something like 1:40 or 5:00."
            case .fieldOutOfRange(let raw):
                return "\"\(raw)\" has a minute or second value out of range."
            }
        }
    }

    /// Parses "M:SS[.d]", "H:MM:SS[.d]", or a plain "SS[.d]" into seconds.
    /// Unlike the Python version, a plain-number input is accepted.
    static func parseTime(_ raw: String) throws -> TimeInterval {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { throw ParseError.empty }

        let parts = s.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch parts.count {
        case 1:
            guard let seconds = Double(parts[0]), seconds >= 0 else {
                throw ParseError.badFormat(raw)
            }
            return seconds
        case 2:
            guard let minutes = Int(parts[0]), minutes >= 0,
                  let seconds = Double(parts[1]), seconds >= 0 else {
                throw ParseError.badFormat(raw)
            }
            guard seconds < 60 else { throw ParseError.fieldOutOfRange(raw) }
            return Double(minutes) * 60 + seconds
        case 3:
            guard let hours = Int(parts[0]), hours >= 0,
                  let minutes = Int(parts[1]), minutes >= 0,
                  let seconds = Double(parts[2]), seconds >= 0 else {
                throw ParseError.badFormat(raw)
            }
            guard minutes < 60, seconds < 60 else {
                throw ParseError.fieldOutOfRange(raw)
            }
            return Double(hours) * 3600 + Double(minutes) * 60 + seconds
        default:
            throw ParseError.badFormat(raw)
        }
    }

    /// Formats a positive `TimeInterval` as "MM:SS.d" or "H:MM:SS.d". Always
    /// shows one decimal of seconds to stay consistent across rows in the UI.
    /// Properly rolls over on 59.95 s and prints integer hours (both bugs in
    /// the Python original).
    static func formatTime(_ interval: TimeInterval) -> String {
        let safe = max(interval, 0)
        let tenths = Int((safe * 10).rounded())
        let subTenths = tenths % 10
        var seconds = tenths / 10
        var minutes = seconds / 60
        seconds = seconds % 60
        let hours = minutes / 60
        minutes = minutes % 60

        let secStr = String(format: "%02d.%d", seconds, subTenths)
        let minStr = String(format: "%02d", minutes)
        if hours > 0 {
            return "\(hours):\(minStr):\(secStr)"
        }
        return "\(minStr):\(secStr)"
    }

    // MARK: - Derivations: given any two of (time, distance, split), find the third.

    /// time = split * (distance / 500)
    static func time(fromDistance distance: Double, split: TimeInterval) -> TimeInterval {
        split * (distance / splitDistance)
    }

    /// distance = time / split * 500
    static func distance(fromTime time: TimeInterval, split: TimeInterval) -> Double {
        time / split * splitDistance
    }

    /// split = time / distance * 500
    static func split(fromTime time: TimeInterval, distance: Double) -> TimeInterval {
        time / distance * splitDistance
    }

    /// Average split across one or more intervals, computed on totals.
    /// Returns nil for empty input or zero distance.
    static func averageSplit(totalTime: TimeInterval, totalDistance: Double) -> TimeInterval? {
        guard totalDistance > 0 else { return nil }
        return totalTime / totalDistance * splitDistance
    }
}
