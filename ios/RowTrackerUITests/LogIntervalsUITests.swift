import XCTest

/// Drives the interval controls on the Log Workout screen the way a rower
/// would: toggles, "+ Add interval", and the (−) remove buttons.
final class LogIntervalsUITests: RowTrackerUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openLogTab()
    }

    // MARK: - Add

    func testAddIntervalWithIntervalsOn() {
        setToggle("intervalsToggle", on: true)
        XCTAssertTrue(appears(intervalTitle(2)))
        XCTAssertFalse(appearsNearAddButton(intervalTitle(3)))

        tapAddInterval()

        XCTAssertTrue(appears(intervalTitle(3)),
                      "Tapping + Add interval should show Interval 3")
    }

    func testAddIntervalWithVariableOn() {
        setToggle("intervalsToggle", on: true)
        setToggle("variableToggle", on: true)
        XCTAssertTrue(appears(intervalTitle(2)))
        XCTAssertFalse(appearsNearAddButton(intervalTitle(3)))

        tapAddInterval()

        XCTAssertTrue(appears(intervalTitle(3)),
                      "Tapping + Add interval should show Interval 3")
        // Variable layout: the new interval gets its own primary field.
        XCTAssertTrue(appears(app.textFields["primaryField.3"]))
    }

    // MARK: - Remove

    func testRemoveDeletesTheTappedInterval() {
        setToggle("intervalsToggle", on: true)
        tapAddInterval()
        XCTAssertTrue(appears(intervalTitle(3)))

        type("2:00", into: "secondaryField.1")
        type("2:05", into: "secondaryField.2")
        type("2:10", into: "secondaryField.3")
        dismissKeyboard()

        tapButton("removeIntervalButton.2")

        XCTAssertFalse(appearsNearAddButton(intervalTitle(3)))
        XCTAssertEqual(value(of: "secondaryField.1"), "2:00")
        XCTAssertEqual(value(of: "secondaryField.2"), "2:10",
                       "Interval 2 should now hold what was Interval 3")
    }

    func testRemoveWithVariableOn() {
        setToggle("intervalsToggle", on: true)
        setToggle("variableToggle", on: true)
        tapAddInterval()
        XCTAssertTrue(appears(intervalTitle(3)))

        type("2:00", into: "secondaryField.1")
        type("2:05", into: "secondaryField.2")
        type("2:10", into: "secondaryField.3")
        dismissKeyboard()

        tapButton("removeIntervalButton.3")

        XCTAssertFalse(appearsNearAddButton(intervalTitle(3)))
        XCTAssertEqual(value(of: "secondaryField.1"), "2:00")
        XCTAssertEqual(value(of: "secondaryField.2"), "2:05")
    }

    func testFirstIntervalHasNoRemoveButton() {
        setToggle("intervalsToggle", on: true)
        XCTAssertTrue(appears(intervalTitle(2)))
        XCTAssertTrue(appears(intervalTitle(1)))
        XCTAssertFalse(app.buttons["removeIntervalButton.1"].exists)
        XCTAssertTrue(appears(app.buttons["removeIntervalButton.2"]))
    }

    // MARK: - Toggles

    func testIntervalsAndVariableToggles() {
        // Off: a single "Workout" box, no Variable toggle, no add button.
        XCTAssertFalse(app.switches["variableToggle"].exists)
        XCTAssertFalse(app.buttons["addIntervalButton"].exists)

        setToggle("intervalsToggle", on: true)
        XCTAssertTrue(app.switches["variableToggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(appears(intervalTitle(2)))
        // Shared layout: interval rows have no primary field of their own.
        XCTAssertTrue(appears(app.textFields["secondaryField.1"]))
        XCTAssertFalse(app.textFields["primaryField.1"].exists)

        setToggle("variableToggle", on: true)
        XCTAssertTrue(appears(app.textFields["primaryField.1"]))
        XCTAssertTrue(appears(app.textFields["primaryField.2"]))

        setToggle("variableToggle", on: false)
        XCTAssertTrue(appears(app.textFields["secondaryField.1"]))
        XCTAssertFalse(app.textFields["primaryField.1"].exists)

        setToggle("intervalsToggle", on: false)
        XCTAssertFalse(app.switches["variableToggle"].exists)
        XCTAssertFalse(app.buttons["addIntervalButton"].exists)
        XCTAssertFalse(appears(intervalTitle(1)))
        XCTAssertFalse(app.textFields["secondaryField.2"].exists)
    }

    // MARK: - Helpers

    private func intervalTitle(_ n: Int) -> XCUIElement {
        app.staticTexts["Interval \(n)"]
    }

    private func tapAddInterval() {
        tapButton("addIntervalButton")
    }

    private func value(of id: String) -> String? {
        scrollTo(app.textFields[id]).value as? String
    }

    /// For checking a row is gone: scroll to the add button (directly below
    /// the last interval) and look there.
    private func appearsNearAddButton(_ element: XCUIElement) -> Bool {
        _ = scrollTo(app.buttons["addIntervalButton"])
        return element.exists
    }
}
