import Foundation
import Testing
@testable import RowTracker

@Suite("Rest between intervals")
struct RestTests {
    /// A Distance workout, 3 intervals of 500 m, splits entered.
    private func threeBy500(variable: Bool = false) -> WorkoutForm {
        var form = WorkoutForm()
        form.kind = .distance
        form.setIntervalsOn(true)
        form.addInterval()
        if variable {
            form.setVariable(true)
            for i in form.rows.indices { form.rows[i].primaryStr = "500" }
        } else {
            form.sharedPrimaryStr = "500"
        }
        form.rows[0].secondaryStr = "1:40"
        form.rows[1].secondaryStr = "1:42"
        form.rows[2].secondaryStr = "1:38"
        return form
    }

    // MARK: Defaults

    @Test("Variable rest defaults off with shared intervals and on with variable ones")
    func defaults() {
        var form = WorkoutForm()
        #expect(!form.showsSharedRest)
        #expect(form.restRowIndices.isEmpty)

        form.setIntervalsOn(true)
        #expect(!form.variableRest)
        #expect(form.showsSharedRest)

        form.setVariable(true)
        #expect(form.variableRest)
        #expect(!form.showsSharedRest)
        #expect(form.restRowIndices == 0..<1)   // two rows: rest after the first only

        form.setVariable(false)
        #expect(!form.variableRest)
    }

    @Test("no rest field after the last interval")
    func noRestAfterLast() {
        var form = WorkoutForm()
        form.setIntervalsOn(true)
        form.setVariableRest(true)
        form.addInterval()
        form.addInterval()
        #expect(form.rows.count == 4)
        #expect(form.restRowIndices == 0..<3)
    }

    // MARK: Saving

    @Test("shared rest applies after every interval but the last")
    func sharedRest() throws {
        var form = threeBy500()
        form.sharedRestStr = "1:00"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.restSec) == [60, 60, nil])
        #expect(w.totalRest == 120)
    }

    @Test("variable rest saves each value; a value typed on the last row is ignored")
    func variableRest() throws {
        var form = threeBy500(variable: true)
        form.rows[0].restStr = "1:00"
        form.rows[1].restStr = "2:30"
        form.rows[2].restStr = "9:99 junk"   // hidden field, never shown or saved
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.map(\.restSec) == [60, 150, nil])
    }

    @Test("blank or zero rest saves as no rest")
    func blankRest() throws {
        var form = threeBy500(variable: true)
        form.rows[0].restStr = ""
        form.rows[1].restStr = "0:00"
        let made = form.makeWorkout()
        #expect(try #require(made).intervals.allSatisfy { $0.restSec == nil })
    }

    @Test("invalid rest shows a message on that field and doesn't save")
    func invalidRest() {
        var variable = threeBy500(variable: true)
        variable.rows[1].restStr = "abc"
        #expect(variable.makeWorkout() == nil)
        #expect(variable.rows[1].restError?.contains("Rest must be a time") == true)
        #expect(variable.rows[0].restError == nil)

        var shared = threeBy500()
        shared.sharedRestStr = "1:75"
        #expect(shared.makeWorkout() == nil)
        #expect(shared.sharedRestError != nil)
    }

    @Test("a single piece (Intervals off) never saves rest")
    func singlePieceNoRest() throws {
        var form = threeBy500()
        form.sharedRestStr = "1:00"
        form.setIntervalsOn(false)
        form.rows[0].primaryStr = "2000"
        let made = form.makeWorkout()
        let w = try #require(made)
        #expect(w.intervals.count == 1)
        #expect(w.intervals[0].restSec == nil)
    }

    @Test("switching Variable rest keeps what was typed")
    func carryValues() {
        var form = threeBy500()
        form.sharedRestStr = "1:00"
        form.setVariableRest(true)
        #expect(form.rows.dropLast().allSatisfy { $0.restStr == "1:00" })

        form.rows[0].restStr = "0:45"
        form.sharedRestStr = ""
        form.setVariableRest(false)
        #expect(form.sharedRestStr == "0:45")
    }

    // MARK: Totals

    @Test("rest is never counted in total time, distance, or split")
    func restExcludedFromTotals() throws {
        var withRest = threeBy500()
        withRest.sharedRestStr = "3:00"
        var noRest = threeBy500()
        let madeA = withRest.makeWorkout()
        let madeB = noRest.makeWorkout()
        let a = try #require(madeA)
        let b = try #require(madeB)

        #expect(a.totalRest == 360)
        #expect(a.totalDuration == b.totalDuration)
        #expect(a.totalDistance == b.totalDistance)
        #expect(a.totalDistance == 1500)
        #expect(a.elapsedDuration == b.elapsedDuration)
        #expect(a.averageSplit == b.averageSplit)
        // 100 + 102 + 98 s over 1500 m -> 100 s / 500 m.
        #expect(a.totalDuration == 300)
        #expect(a.averageSplit == 100)
        #expect(a.intervals.map(\.splitSec) == b.intervals.map(\.splitSec))
    }

    @Test("parseRest accepts times like other fields")
    func parseRest() throws {
        #expect(try WorkoutForm.parseRest("1:00") == 60)
        #expect(try WorkoutForm.parseRest("90") == 90)
        #expect(try WorkoutForm.parseRest(" 0:45 ") == 45)
        #expect(try WorkoutForm.parseRest("") == nil)
        #expect(try WorkoutForm.parseRest("0") == nil)
        #expect(throws: (any Error).self) { try WorkoutForm.parseRest("-1:00") }
        #expect(throws: (any Error).self) { try WorkoutForm.parseRest("1:60") }
    }
}
