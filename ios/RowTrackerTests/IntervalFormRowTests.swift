import Foundation
import Testing
@testable import RowTracker

@Suite("IntervalFormRow derivation")
struct IntervalFormRowTests {
    @Test("Timed + split derives distance")
    func timedWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        let interval = try row.derive(kind: .timed)
        #expect(interval.durationSec == 300)
        // 300s @ 1:40/500m = 300/100 * 500 = 1500m
        #expect(interval.distanceMeters == 1500)
    }

    @Test("Timed + distance stores both as-is")
    func timedWithDistance() throws {
        var row = IntervalFormRow()
        row.primaryStr = "20:00"
        row.secondaryStr = "5000"
        let interval = try row.derive(kind: .timed, secondary: .otherQuantity)
        #expect(interval.durationSec == 1200)
        #expect(interval.distanceMeters == 5000)
    }

    @Test("Distance + split derives time")
    func distanceWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondaryStr = "1:50"
        let interval = try row.derive(kind: .distance)
        #expect(interval.distanceMeters == 2000)
        // 2000m @ 1:50/500m: time = 110 * (2000/500) = 110 * 4 = 440s
        #expect(interval.durationSec == 440)
    }

    @Test("Distance + time stores both as-is")
    func distanceWithTime() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondaryStr = "7:48"
        let interval = try row.derive(kind: .distance, secondary: .otherQuantity)
        #expect(interval.distanceMeters == 2000)
        #expect(interval.durationSec == 468)
    }

    @Test("Missing primary throws")
    func missingPrimary() {
        var row = IntervalFormRow()
        row.secondaryStr = "1:40"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Missing secondary throws")
    func missingSecondary() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Zero split rejected")
    func zeroSplit() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "0:00"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Garbage distance in distance workout rejected")
    func badDistance() {
        var row = IntervalFormRow()
        row.primaryStr = "banana"
        row.secondaryStr = "1:50"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .distance)
        }
    }

    // MARK: - Stroke rate

    @Test("Blank stroke rate stays nil, not zero")
    func strokeRateBlankIsNil() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = ""
        let interval = try row.derive(kind: .timed)
        #expect(interval.strokeRate == nil)
    }

    @Test("Whitespace-only stroke rate stays nil")
    func strokeRateWhitespaceIsNil() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = "   "
        let interval = try row.derive(kind: .timed)
        #expect(interval.strokeRate == nil)
    }

    @Test("Valid stroke rate parses as Int")
    func strokeRateValid() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = "28"
        let interval = try row.derive(kind: .timed)
        #expect(interval.strokeRate == 28)
    }

    @Test("Boundary stroke rates (10 and 60) are accepted")
    func strokeRateBoundaries() throws {
        for value in [10, 60] {
            var row = IntervalFormRow()
            row.primaryStr = "5:00"
                row.secondaryStr = "1:40"
            row.strokeRateStr = "\(value)"
            let interval = try row.derive(kind: .timed)
            #expect(interval.strokeRate == value)
        }
    }

    @Test("Below range rejected")
    func strokeRateTooLow() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = "9"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Above range rejected")
    func strokeRateTooHigh() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = "61"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Non-integer stroke rate rejected")
    func strokeRateNotInt() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondaryStr = "1:40"
        row.strokeRateStr = "28.5"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Stroke-rate error message mentions range 10 to 60")
    func strokeRateErrorMessage() {
        var row = IntervalFormRow()
        row.strokeRateStr = "100"
        do {
            _ = try row.parseStrokeRate()
            Issue.record("expected throw")
        } catch let e as IntervalFormRow.DeriveError {
            let msg = e.errorDescription ?? ""
            #expect(msg.contains("10") && msg.contains("60"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Suite("WorkoutForm intervals toggle")
struct WorkoutFormIntervalsToggleTests {
    private func filled(_ primary: String, _ split: String) -> IntervalFormRow {
        var r = IntervalFormRow()
        r.primaryStr = primary
        r.secondaryStr = split
        return r
    }

    @Test("Intervals default off with one row")
    func defaults() {
        let form = WorkoutForm()
        #expect(form.intervalsOn == false)
        #expect(form.activeRowIndices == 0..<1)
    }

    @Test("Turning intervals on adds a second interval")
    func turnOn() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        #expect(form.rows.count == 2)
        #expect(form.activeRowIndices == 0..<2)
    }

    @Test("Turning intervals off saves only the first row and keeps the rest")
    func offSavesFirstOnly() throws {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.rows = [filled("5:00", "1:40"), IntervalFormRow()]   // 2nd blank
        form.setIntervalsOn(false)
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.count == 1)
        #expect(form.rows.count == 2, "hidden rows are kept")
        form.setIntervalsOn(true)
        let again = form.makeWorkout()
        #expect(again == nil, "blank 2nd interval now counts")
    }
}

@Suite("WorkoutForm variable toggle")
struct WorkoutFormVariableToggleTests {
    @Test("Layout follows the two toggles")
    func layouts() {
        var form = WorkoutForm()
        #expect(form.layout == .single)
        form.setIntervalsOn(true)
        #expect(form.layout == .uniform)
        form.setVariable(true)
        #expect(form.layout == .variable)
        form.setIntervalsOn(false)
        #expect(form.layout == .single, "Variable is ignored with intervals off")
    }

    @Test("Single -> shared: the value moves to the shared field")
    func singleToShared() {
        var form = WorkoutForm()
        form.rows[0].primaryStr = "5:00"
        form.setIntervalsOn(true)
        #expect(form.sharedPrimaryStr == "5:00")
    }

    @Test("Shared -> variable: every interval gets the shared value")
    func sharedToVariable() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.sharedPrimaryStr = "2:00"
        form.setVariable(true)
        #expect(form.rows.map(\.primaryStr) == ["2:00", "2:00"])
    }

    @Test("Variable -> shared -> variable without editing keeps each value")
    func variableRoundTrip() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.setVariable(true)
        form.rows[0].primaryStr = "1:00"
        form.rows[1].primaryStr = "2:00"
        form.setVariable(false)
        #expect(form.sharedPrimaryStr == "1:00")
        form.setVariable(true)
        #expect(form.rows.map(\.primaryStr) == ["1:00", "2:00"])
    }

    @Test("Editing the shared value overwrites the per-interval values")
    func editedSharedWins() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.setVariable(true)
        form.rows[0].primaryStr = "1:00"
        form.rows[1].primaryStr = "2:00"
        form.setVariable(false)
        form.sharedPrimaryStr = "3:00"
        form.setVariable(true)
        #expect(form.rows.map(\.primaryStr) == ["3:00", "3:00"])
    }

    @Test("Shared -> intervals off: the single box gets the shared value")
    func sharedToSingle() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.sharedPrimaryStr = "500"
        form.kind = .distance
        form.setIntervalsOn(false)
        #expect(form.rows[0].primaryStr == "500")
    }

    @Test("Secondary and stroke-rate values survive every layout change")
    func secondaryKept() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.rows[0].secondaryStr = "1:45"
        form.rows[1].secondaryStr = "1:50"
        form.rows[1].strokeRateStr = "30"
        form.setVariable(true)
        form.setVariable(false)
        form.setIntervalsOn(false)
        form.setIntervalsOn(true)
        #expect(form.rows.map(\.secondaryStr) == ["1:45", "1:50"])
        #expect(form.rows[1].strokeRateStr == "30")
    }

    @Test("Blank shared value is reported once, on the shared field")
    func blankShared() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.rows[0].secondaryStr = "1:45"
        form.rows[1].secondaryStr = "1:50"
        let w = form.makeWorkout()
        #expect(w == nil)
        #expect(form.sharedPrimaryError != nil)
        #expect(form.rows.allSatisfy { $0.error == nil })
    }
}

@Suite("Secondary metric: watts and switching")
struct SecondaryMetricTests {
    @Test("Timed + watts derives distance through the split")
    func timedWithWatts() throws {
        var row = IntervalFormRow()
        row.primaryStr = "10:00"
        row.secondaryStr = "202.546"          // = 2:00.0 split
        let interval = try row.derive(kind: .timed, secondary: .watts)
        #expect(interval.durationSec == 600)
        // 600 s at 2:00/500 m = 2500 m
        #expect(interval.distanceMeters == 2500)
    }

    @Test("Distance + watts derives time through the split")
    func distanceWithWatts() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondaryStr = "202.546"
        let interval = try row.derive(kind: .distance, secondary: .watts)
        #expect(interval.distanceMeters == 2000)
        #expect(abs(interval.durationSec - 480) < 0.01)
    }

    @Test("Watts must be greater than zero", arguments: ["0", "-150", "abc"])
    func badWatts(_ text: String) {
        var row = IntervalFormRow()
        row.primaryStr = "10:00"
        row.secondaryStr = text
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed, secondary: .watts)
        }
    }

    @Test("Split defaults, and applies to every interval")
    func formLevel() throws {
        var form = WorkoutForm()
        #expect(form.secondary == .split)
        form.setIntervalsOn(true)
        form.setVariable(true)
        form.rows[0].primaryStr = "5:00"; form.rows[0].secondaryStr = "1:40"
        form.rows[1].primaryStr = "5:00"; form.rows[1].secondaryStr = "1:50"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.distanceMeters) == [1500, 1364])
    }

    @Test("Switching split -> watts -> split converts the typed value")
    func splitWattsSwitch() {
        var form = WorkoutForm()
        form.rows[0].secondaryStr = "2:00"
        form.setSecondary(.watts)
        #expect(form.rows[0].secondaryStr == "202.5")
        form.setSecondary(.split)
        #expect(form.rows[0].secondaryStr == "02:00.0")
    }

    @Test("Switching split -> other uses the primary value")
    func splitToOther() {
        var form = WorkoutForm()
        form.rows[0].primaryStr = "5:00"
        form.rows[0].secondaryStr = "1:40"
        form.setSecondary(.otherQuantity)
        #expect(form.rows[0].secondaryStr == "1500")
    }

    @Test("A value that can't be converted is left as typed")
    func unconvertibleKept() {
        var form = WorkoutForm()
        form.rows[0].secondaryStr = "1500"     // distance, but no primary
        form.setSecondary(.otherQuantity)      // "1500" isn't a valid split
        #expect(form.rows[0].secondaryStr == "1500")
    }
}
