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

@Suite("WorkoutForm derivation in each layout")
struct WorkoutFormLayoutDerivationTests {
    @Test("Layout a (single): one interval from the one box")
    func single() throws {
        var form = WorkoutForm()
        form.kind = .distance
        form.rows[0].primaryStr = "2000"
        form.rows[0].secondaryStr = "1:50"
        form.rows[0].strokeRateStr = "30"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.count == 1)
        #expect(w.intervals[0].distanceMeters == 2000)
        #expect(w.intervals[0].durationSec == 440)
        #expect(w.intervals[0].strokeRate == 30)
    }

    @Test("Layout b (shared): every interval uses the shared primary")
    func shared() throws {
        var form = WorkoutForm()
        form.kind = .timed
        form.setIntervalsOn(true)
        form.addInterval()
        form.sharedPrimaryStr = "4:00"
        form.rows[0].secondaryStr = "1:40"     // 1200 m
        form.rows[1].secondaryStr = "2:00"     // 1000 m
        form.rows[2].secondaryStr = "1:36"     // 1250 m
        form.rows[2].strokeRateStr = "28"
        // A stale per-row primary must be ignored in this layout.
        form.rows[1].primaryStr = "9:99"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.durationSec) == [240, 240, 240])
        #expect(w.intervals.map(\.distanceMeters) == [1200, 1000, 1250])
        #expect(w.intervals.map(\.strokeRate) == [nil, nil, 28])
    }

    @Test("Layout b with watts")
    func sharedWithWatts() throws {
        var form = WorkoutForm()
        form.kind = .distance
        form.setIntervalsOn(true)
        form.setSecondary(.watts)
        form.sharedPrimaryStr = "500"
        form.rows[0].secondaryStr = "202.546"   // 2:00.0
        form.rows[1].secondaryStr = "302.343"   // 1:45.0
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.distanceMeters) == [500, 500])
        #expect(abs(w.intervals[0].durationSec - 120) < 0.01)
        #expect(abs(w.intervals[1].durationSec - 105) < 0.01)
    }

    @Test("Layout c (variable): each interval uses its own primary")
    func variable() throws {
        var form = WorkoutForm()
        form.kind = .distance
        form.setIntervalsOn(true)
        form.setVariable(true)
        form.setSecondary(.otherQuantity)        // Time
        form.rows[0].primaryStr = "1000"; form.rows[0].secondaryStr = "3:30"
        form.rows[1].primaryStr = "500";  form.rows[1].secondaryStr = "1:40"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.distanceMeters) == [1000, 500])
        #expect(w.intervals.map(\.durationSec) == [210, 100])
    }

    @Test("Layout c reports a bad row on that row only")
    func variableRowError() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.setVariable(true)
        form.rows[0].primaryStr = "5:00"; form.rows[0].secondaryStr = "1:40"
        form.rows[1].primaryStr = "";     form.rows[1].secondaryStr = "1:40"
        let w = form.makeWorkout()
        #expect(w == nil)
        #expect(form.rows[0].error == nil)
        #expect(form.rows[1].error != nil)
    }

    @Test("Add and remove intervals; the first can't be removed")
    func addRemove() {
        var form = WorkoutForm()
        form.addInterval()
        #expect(form.rows.count == 1, "no adding with intervals off")
        form.setIntervalsOn(true)
        form.addInterval()
        #expect(form.rows.count == 3)
        let firstID = form.rows[0].id
        let secondID = form.rows[1].id
        form.removeInterval(id: firstID)
        #expect(form.rows.count == 3)
        form.removeInterval(id: secondID)
        #expect(form.rows.count == 2)
        #expect(!form.rows.contains { $0.id == secondID })
    }

    @Test("At most 20 intervals")
    func maxIntervals() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        for _ in 0..<30 { form.addInterval() }
        #expect(form.rows.count == WorkoutForm.maxIntervals)
        #expect(!form.canAddInterval)
    }
}
