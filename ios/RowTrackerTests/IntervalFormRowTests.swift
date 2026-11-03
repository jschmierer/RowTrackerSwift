import Foundation
import Testing
@testable import RowTracker

@Suite("IntervalFormRow derivation")
struct IntervalFormRowTests {
    @Test("Timed + split derives distance")
    func timedWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
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
        row.secondary = .otherQuantity
        row.secondaryStr = "5000"
        let interval = try row.derive(kind: .timed)
        #expect(interval.durationSec == 1200)
        #expect(interval.distanceMeters == 5000)
    }

    @Test("Distance + split derives time")
    func distanceWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondary = .split
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
        row.secondary = .otherQuantity
        row.secondaryStr = "7:48"
        let interval = try row.derive(kind: .distance)
        #expect(interval.distanceMeters == 2000)
        #expect(interval.durationSec == 468)
    }

    @Test("Missing primary throws")
    func missingPrimary() {
        var row = IntervalFormRow()
        row.secondary = .split
        row.secondaryStr = "1:40"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Missing secondary throws")
    func missingSecondary() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Zero split rejected")
    func zeroSplit() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        row.secondaryStr = "0:00"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Garbage distance in distance workout rejected")
    func badDistance() {
        var row = IntervalFormRow()
        row.primaryStr = "banana"
        row.secondary = .split
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
        row.secondary = .split
        row.secondaryStr = "1:40"
        row.strokeRateStr = ""
        let interval = try row.derive(kind: .timed)
        #expect(interval.strokeRate == nil)
    }

    @Test("Whitespace-only stroke rate stays nil")
    func strokeRateWhitespaceIsNil() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        row.secondaryStr = "1:40"
        row.strokeRateStr = "   "
        let interval = try row.derive(kind: .timed)
        #expect(interval.strokeRate == nil)
    }

    @Test("Valid stroke rate parses as Int")
    func strokeRateValid() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
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
            row.secondary = .split
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
        row.secondary = .split
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
        row.secondary = .split
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
        row.secondary = .split
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
        r.secondary = .split
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
