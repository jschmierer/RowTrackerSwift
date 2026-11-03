import Foundation

/// Everything the Log Workout form holds, plus the rules for turning it into
/// a `Workout`. Pure Swift (no SwiftUI) so it can be unit tested; the view
/// only lays it out and binds to it.
struct WorkoutForm {
    var date: Date = Date()
    var kind: WorkoutKind = .timed
    /// Off: one box for a single piece. On: a list of intervals.
    private(set) var intervalsOn = false
    /// Only meaningful with intervals on. Off: every interval shares one
    /// primary value (`sharedPrimaryStr`). On: each row has its own.
    private(set) var variable = false
    /// "Time per interval" / "Distance per interval" in the shared layout.
    var sharedPrimaryStr: String = ""
    var sharedPrimaryError: String?
    /// What the rower enters besides the primary value, for every interval.
    private(set) var secondary: SecondaryField = .split
    /// `sharedPrimaryStr` as it was when the shared layout was entered, so
    /// leaving it can tell whether the rower changed it.
    private var sharedPrimaryBaseline: String = ""
    /// Every row the rower has filled in. With intervals off only the first
    /// is shown and saved; the rest are kept so turning intervals back on
    /// restores them.
    var rows: [IntervalFormRow] = [IntervalFormRow()]
    /// Heart rate is per workout, not per interval.
    var recordHeartRate = false
    var avgHRStr: String = ""
    var maxHRStr: String = ""
    var heartRateError: String?
    /// Perceived effort, 0 (easy) to 10 (all-out).
    var effort: Int = 5 {
        didSet { effort = min(max(effort, Self.effortRange.lowerBound), Self.effortRange.upperBound) }
    }
    var notes: String = ""

    static let maxIntervals = 20
    /// Accepted heart-rate range (beats per minute).
    static let heartRateRange = 30...230
    static let effortRange = 0...10

    /// The three ways the interval entry can be laid out.
    enum Layout: Equatable {
        /// Intervals off: one box with primary, secondary, stroke rate.
        case single
        /// Intervals on, Variable off: one shared primary field, then per
        /// interval only the secondary value and stroke rate.
        case uniform
        /// Intervals on, Variable on: every interval has all three fields.
        case variable
    }

    var layout: Layout {
        guard intervalsOn else { return .single }
        return variable ? .variable : .uniform
    }

    /// Indices of the rows the current layout shows (and saves).
    var activeRowIndices: Range<Int> {
        intervalsOn ? rows.indices : 0..<1
    }

    mutating func setIntervalsOn(_ on: Bool) {
        let old = layout
        intervalsOn = on
        // An interval workout has at least two pieces; start with a blank
        // second one rather than making the rower tap "add" straight away.
        if on && rows.count < 2 {
            rows.append(IntervalFormRow())
        }
        carryPrimaryValues(from: old, to: layout)
    }

    mutating func setVariable(_ on: Bool) {
        let old = layout
        variable = on
        carryPrimaryValues(from: old, to: layout)
    }

    /// Changes the secondary metric. Values already typed are converted to
    /// the new metric where that's possible (split and watts always; the
    /// other quantity when the primary value is valid). A value that can't
    /// be converted is left as typed for the rower to fix.
    mutating func setSecondary(_ new: SecondaryField) {
        let old = secondary
        guard new != old else { return }
        for i in rows.indices {
            if let converted = convertedSecondary(row: rows[i], from: old, to: new) {
                rows[i].secondaryStr = converted
            }
        }
        secondary = new
    }

    private func convertedSecondary(row: IntervalFormRow,
                                    from old: SecondaryField,
                                    to new: SecondaryField) -> String? {
        let text = row.secondaryStr.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // Split <-> watts needs nothing else.
        if old != .otherQuantity, new != .otherQuantity,
           let split = try? IntervalFormRow.parseSplit(text, as: old) {
            return Self.format(split: split, as: new)
        }
        // Anything involving the other quantity needs the whole interval.
        let primary = layout == .uniform ? sharedPrimaryStr : row.primaryStr
        var probe = row
        probe.strokeRateStr = ""      // irrelevant to the conversion
        guard let interval = try? probe.derive(kind: kind, secondary: old,
                                               primaryOverride: primary),
              let split = interval.splitSec else { return nil }
        switch new {
        case .otherQuantity:
            switch kind {
            case .timed:
                return String(Int((interval.distanceMeters ?? 0).rounded()))
            case .distance:
                return RowingMath.formatTime(interval.durationSec)
            }
        case .split, .watts:
            return Self.format(split: split, as: new)
        }
    }

    private static func format(split: TimeInterval, as field: SecondaryField) -> String? {
        switch field {
        case .split:
            return RowingMath.formatTime(split)
        case .watts:
            // One decimal so split -> watts -> split lands on the same tenth.
            return RowingMath.watts(fromSplit: split).map { watts in
                let tenths = (watts * 10).rounded() / 10
                return tenths == tenths.rounded()
                    ? String(Int(tenths))
                    : String(format: "%.1f", tenths)
            }
        case .otherQuantity:
            return nil
        }
    }

    /// Keeps entered primary values when the layout changes.
    ///
    /// - Entering the shared layout: the shared field takes the first
    ///   interval's value (if it has one).
    /// - Leaving it: intervals with a blank primary take the shared value,
    ///   and if the rower edited the shared value, every interval takes it
    ///   (that is what the form showed them). If they didn't touch it, the
    ///   per-interval values from before come back unchanged.
    private mutating func carryPrimaryValues(from old: Layout, to new: Layout) {
        guard old != new else { return }
        if new == .uniform {
            let first = rows[0].primaryStr.trimmingCharacters(in: .whitespaces)
            if !first.isEmpty { sharedPrimaryStr = rows[0].primaryStr }
            sharedPrimaryBaseline = sharedPrimaryStr
            sharedPrimaryError = nil
        } else if old == .uniform {
            let edited = sharedPrimaryStr != sharedPrimaryBaseline
            for i in rows.indices {
                let blank = rows[i].primaryStr.trimmingCharacters(in: .whitespaces).isEmpty
                if edited || blank { rows[i].primaryStr = sharedPrimaryStr }
            }
        }
    }

    var canAddInterval: Bool { rows.count < Self.maxIntervals }

    /// Appends a blank interval (intervals layouts only).
    mutating func addInterval() {
        guard intervalsOn, canAddInterval else { return }
        rows.append(IntervalFormRow())
    }

    /// Removes an interval. The first one can't be removed.
    mutating func removeInterval(id: IntervalFormRow.ID) {
        guard let i = rows.firstIndex(where: { $0.id == id }), i > 0 else { return }
        rows.remove(at: i)
    }

    /// Validates the active rows, stores a per-row error message on each
    /// one that fails, and returns the workout when everything is valid.
    mutating func makeWorkout() -> Workout? {
        var intervals: [Interval] = []
        var hadError = false

        // Shared layout: check the shared field once, not on every row.
        var override: String?
        sharedPrimaryError = nil
        if layout == .uniform {
            let text = sharedPrimaryStr.trimmingCharacters(in: .whitespaces)
            do {
                guard !text.isEmpty else {
                    throw IntervalFormRow.DeriveError.missing(kind.primaryFieldName)
                }
                _ = try IntervalFormRow.parsePrimary(text, kind: kind)
                override = text
            } catch {
                sharedPrimaryError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                hadError = true
            }
        }

        for i in rows.indices {
            guard activeRowIndices.contains(i), !(layout == .uniform && override == nil) else {
                rows[i].error = nil
                continue
            }
            do {
                intervals.append(try rows[i].derive(kind: kind,
                                                    secondary: secondary,
                                                    primaryOverride: override))
                rows[i].error = nil
            } catch {
                rows[i].error = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                hadError = true
            }
        }
        // Heart rate: ignored entirely while the toggle is off (anything
        // typed is kept on the form but not saved).
        var avgHR: Int?
        var maxHR: Int?
        heartRateError = nil
        if recordHeartRate {
            do {
                (avgHR, maxHR) = try Self.parseHeartRate(avg: avgHRStr, max: maxHRStr)
            } catch {
                heartRateError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                hadError = true
            }
        }

        guard !hadError else { return nil }
        return Workout(kind: kind,
                       date: RowingDate.startOfLocalDay(for: date),
                       notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                       intervals: intervals,
                       avgHR: avgHR,
                       maxHR: maxHR,
                       effort: effort)
    }

    /// Each field is optional (blank saves as nil, like stroke rate). A
    /// value must be a whole number from 30 to 230 bpm, and max can't be
    /// below average when both are given.
    static func parseHeartRate(avg: String, max: String) throws -> (avg: Int?, max: Int?) {
        let a = try parseOneHeartRate(avg, name: "Average HR")
        let m = try parseOneHeartRate(max, name: "Max HR")
        if let a, let m, m < a {
            throw IntervalFormRow.DeriveError.message(
                "Max HR (\(m)) can't be lower than average HR (\(a)).")
        }
        return (a, m)
    }

    private static func parseOneHeartRate(_ text: String, name: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), heartRateRange.contains(value) else {
            throw IntervalFormRow.DeriveError.message(
                "\(name) must be a whole number from 30 to 230 bpm.")
        }
        return value
    }
}

// MARK: - Form row

/// One interval's inputs: the primary value (time for a Timed workout,
/// distance for a Distance workout) plus one secondary (split or the other
/// quantity). The third value is derived in `derive(kind:)`.
struct IntervalFormRow: Identifiable {
    let id = UUID()
    var primaryStr: String = ""
    /// The secondary value as typed; its meaning is the form-level
    /// `WorkoutForm.secondary` (split, the other quantity, or watts).
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

    /// Builds the interval from the primary value plus `secondary`.
    /// `primaryOverride` supplies the primary value when it lives outside
    /// the row (the shared "per interval" field).
    ///
    /// Only distance and duration are stored. Watts are converted to a
    /// split first, then handled exactly like a split.
    func derive(kind: WorkoutKind,
                secondary: SecondaryField = .split,
                primaryOverride: String? = nil) throws -> Interval {
        let primaryText = (primaryOverride ?? primaryStr)
            .trimmingCharacters(in: .whitespaces)
        let secondaryText = secondaryStr.trimmingCharacters(in: .whitespaces)
        guard !primaryText.isEmpty else {
            throw DeriveError.missing(kind.primaryFieldName)
        }
        guard !secondaryText.isEmpty else {
            throw DeriveError.missing(secondary.fieldName(for: kind))
        }

        let strokeRate = try parseStrokeRate()
        let primary = try Self.parsePrimary(primaryText, kind: kind)

        switch (kind, secondary) {
        case (.timed, .split), (.timed, .watts):
            let time = primary
            let split = try Self.parseSplit(secondaryText, as: secondary)
            let distance = RowingMath.distance(fromTime: time, split: split).rounded()
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.timed, .otherQuantity):
            // Timed + distance
            let distance = try Self.parseDistance(secondaryText)
            return Interval(durationSec: primary, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .split), (.distance, .watts):
            let distance = primary
            let split = try Self.parseSplit(secondaryText, as: secondary)
            let time = RowingMath.time(fromDistance: distance, split: split)
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .otherQuantity):
            // Distance + time
            let time = try Self.parsePositiveTime(secondaryText, name: "Time")
            return Interval(durationSec: time, distanceMeters: primary, strokeRate: strokeRate)
        }
    }

    /// A split in seconds per 500 m, from either a typed split or watts.
    static func parseSplit(_ text: String, as field: SecondaryField) throws -> TimeInterval {
        if field == .watts {
            let watts = try parseWatts(text)
            guard let split = RowingMath.split(fromWatts: watts) else {
                throw DeriveError.message("Watts must be a number greater than 0.")
            }
            return split
        }
        return try parsePositiveTime(text, name: "Split")
    }

    static func parseWatts(_ text: String) throws -> Double {
        guard let watts = Double(text.trimmingCharacters(in: .whitespaces)),
              watts > 0, watts.isFinite else {
            throw DeriveError.message("Watts must be a number greater than 0.")
        }
        return watts
    }

    /// The primary value: seconds for a Timed workout, meters for a
    /// Distance workout. Throws a friendly message when invalid.
    static func parsePrimary(_ text: String, kind: WorkoutKind) throws -> Double {
        switch kind {
        case .timed: return try parsePositiveTime(text, name: "Time")
        case .distance: return try parseDistance(text)
        }
    }

    static func parsePositiveTime(_ text: String, name: String) throws -> TimeInterval {
        let value = try RowingMath.parseTime(text)
        guard value > 0 else {
            throw DeriveError.message("\(name) must be greater than zero.")
        }
        return value
    }

    static func parseDistance(_ text: String) throws -> Double {
        guard let distance = Double(text.trimmingCharacters(in: .whitespaces)),
              distance > 0, distance.isFinite else {
            throw DeriveError.message("Distance must be a positive number of meters.")
        }
        return distance
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
enum SecondaryField: Hashable, CaseIterable {
    case split
    case otherQuantity   // "distance" for a Timed workout, "time" for a Distance workout
    case watts           // converted to a split, never stored
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
    func fieldName(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "split"
        case (.otherQuantity, .timed): return "distance"
        case (.otherQuantity, .distance): return "time"
        case (.watts, _): return "watts"
        }
    }
}
