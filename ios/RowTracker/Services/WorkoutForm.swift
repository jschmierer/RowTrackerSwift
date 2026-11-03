import Foundation

/// Everything the Log Workout form holds, plus the rules for turning it into
/// a `Workout`. Pure Swift (no SwiftUI) so it can be unit tested; the view
/// only lays it out and binds to it.
struct WorkoutForm {
    var date: Date = Date()
    var kind: WorkoutKind = .timed
    /// Off: one box for a single piece. On: a list of intervals.
    private(set) var intervalsOn = false
    /// Every row the rower has filled in. With intervals off only the first
    /// is shown and saved; the rest are kept so turning intervals back on
    /// restores them.
    var rows: [IntervalFormRow] = [IntervalFormRow()]
    var notes: String = ""

    static let maxIntervals = 20

    /// Indices of the rows the current layout shows (and saves).
    var activeRowIndices: Range<Int> {
        intervalsOn ? rows.indices : 0..<1
    }

    mutating func setIntervalsOn(_ on: Bool) {
        intervalsOn = on
        // An interval workout has at least two pieces; start with a blank
        // second one rather than making the rower tap "add" straight away.
        if on && rows.count < 2 {
            rows.append(IntervalFormRow())
        }
    }

    mutating func setIntervalCount(_ n: Int) {
        let n = min(max(n, 1), Self.maxIntervals)
        if n > rows.count {
            rows.append(contentsOf: (rows.count..<n).map { _ in IntervalFormRow() })
        } else if n < rows.count {
            rows = Array(rows.prefix(n))
        }
    }

    /// Validates the active rows, stores a per-row error message on each
    /// one that fails, and returns the workout when everything is valid.
    mutating func makeWorkout() -> Workout? {
        var intervals: [Interval] = []
        var hadError = false
        for i in rows.indices {
            guard activeRowIndices.contains(i) else {
                rows[i].error = nil
                continue
            }
            do {
                intervals.append(try rows[i].derive(kind: kind))
                rows[i].error = nil
            } catch {
                rows[i].error = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                hadError = true
            }
        }
        guard !hadError else { return nil }
        return Workout(kind: kind,
                       date: RowingDate.startOfLocalDay(for: date),
                       notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                       intervals: intervals)
    }
}

// MARK: - Form row

/// One interval's inputs: the primary value (time for a Timed workout,
/// distance for a Distance workout) plus one secondary (split or the other
/// quantity). The third value is derived in `derive(kind:)`.
struct IntervalFormRow: Identifiable {
    let id = UUID()
    var primaryStr: String = ""
    var secondary: SecondaryField = .split
    var secondaryStr: String = ""
    /// Stroke rate (spm). Optional on the form — blank saves as nil.
    var strokeRateStr: String = ""
    var error: String?

    /// Accepted stroke-rate range (strokes per minute).
    static let strokeRateRange = 10...60

    enum DeriveError: LocalizedError {
        case missing(String)
        case message(String)

        var errorDescription: String? {
            switch self {
            case .missing(let field): return "Enter a value for \(field)."
            case .message(let m): return m
            }
        }
    }

    func derive(kind: WorkoutKind) throws -> Interval {
        let primary = primaryStr.trimmingCharacters(in: .whitespaces)
        let secondaryText = secondaryStr.trimmingCharacters(in: .whitespaces)
        guard !primary.isEmpty else {
            throw DeriveError.missing(kind.primaryFieldName)
        }
        guard !secondaryText.isEmpty else {
            throw DeriveError.missing(secondary.fieldName)
        }

        let strokeRate = try parseStrokeRate()

        switch (kind, secondary) {
        case (.timed, .split):
            let time = try RowingMath.parseTime(primary)
            let split = try RowingMath.parseTime(secondaryText)
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            guard split > 0 else { throw DeriveError.message("Split must be greater than zero.") }
            let distance = RowingMath.distance(fromTime: time, split: split).rounded()
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.timed, .otherQuantity):
            // Timed + distance
            let time = try RowingMath.parseTime(primary)
            guard let distance = Double(secondaryText), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .split):
            guard let distance = Double(primary), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            let split = try RowingMath.parseTime(secondaryText)
            guard split > 0 else { throw DeriveError.message("Split must be greater than zero.") }
            let time = RowingMath.time(fromDistance: distance, split: split)
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .otherQuantity):
            // Distance + time
            guard let distance = Double(primary), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            let time = try RowingMath.parseTime(secondaryText)
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)
        }
    }

    /// Returns nil for a blank field (so the stored column stays NULL), the
    /// parsed value for an in-range integer, and throws a friendly message
    /// otherwise.
    func parseStrokeRate() throws -> Int? {
        let trimmed = strokeRateStr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), Self.strokeRateRange.contains(value) else {
            throw DeriveError.message("Stroke rate must be a whole number from 10 to 60.")
        }
        return value
    }
}

/// Which secondary value the rower is entering. The third value is computed
/// from the primary (set by the workout type) and this one.
enum SecondaryField: Hashable {
    case split
    case otherQuantity   // "distance" for a Timed workout, "time" for a Distance workout
}


// MARK: - Names used in validation messages

extension WorkoutKind {
    var primaryFieldName: String {
        switch self {
        case .timed: return "time"
        case .distance: return "distance"
        }
    }
}

extension SecondaryField {
    /// Prose label used in error messages ("Enter a value for <this>").
    var fieldName: String {
        switch self {
        case .split: return "split"
        case .otherQuantity: return "the other value"
        }
    }
}
