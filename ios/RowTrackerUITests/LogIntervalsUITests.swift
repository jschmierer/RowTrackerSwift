import XCTest

/// Drives the interval controls on the Log Workout screen the way a rower
/// would: toggles, "+ Add interval", and the (−) remove buttons.
final class LogIntervalsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Log Workout"].waitForExistence(timeout: 5))
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

    private func tapButton(_ id: String) {
        let button = scrollTo(app.buttons[id])
        XCTAssertTrue(button.isHittable, "\(id) should be on screen")
        button.tap()
    }

    private func setToggle(_ id: String, on: Bool) {
        // The toggles sit at the top of the form; scroll back up to them.
        let toggle = app.switches[id]
        var swipes = 0
        let navBar = app.navigationBars["Log Workout"]
        // isHittable can be true while the row is under the navigation bar,
        // so also require it to be below the bar.
        while !(toggle.exists && toggle.isHittable
                && toggle.frame.minY >= navBar.frame.maxY) && swipes < 8 {
            app.swipeDown(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "\(id) missing")
        guard isOn(toggle) != on else { return }
        // Tap the switch control itself, not the label.
        toggle.switches.firstMatch.tap()
        let flipped = NSPredicate { _, _ in self.isOn(toggle) == on }
        let result = XCTWaiter.wait(for: [expectation(for: flipped, evaluatedWith: nil)],
                                    timeout: 2)
        XCTAssertEqual(result, .completed, "\(id) did not turn \(on ? "on" : "off")")
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    private func type(_ text: String, into id: String) {
        // Close any open keyboard first: it can cover the next field while
        // XCUITest still reports that field as hittable.
        dismissKeyboard()
        let field = scrollTo(app.textFields[id])
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "Keyboard didn't appear for \(id)")
        field.typeText(text)
    }

    private func value(of id: String) -> String? {
        scrollTo(app.textFields[id]).value as? String
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.toolbars.buttons["Done"]
        if done.exists { done.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    /// Swipes the form until the element is on screen (or gives up).
    @discardableResult
    private func scrollTo(_ element: XCUIElement) -> XCUIElement {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 8 {
            let above = element.exists && element.frame.maxY < app.windows.firstMatch.frame.midY
            if above {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            swipes += 1
        }
        return element
    }

    /// True once the element is scrolled on screen. Form rows are lazy, so
    /// an off-screen row doesn't exist in the accessibility tree at all.
    private func appears(_ element: XCUIElement) -> Bool {
        _ = element.waitForExistence(timeout: 1)
        return scrollTo(element).exists
    }

    /// For checking a row is gone: scroll to the add button (directly below
    /// the last interval) and look there.
    private func appearsNearAddButton(_ element: XCUIElement) -> Bool {
        _ = scrollTo(app.buttons["addIntervalButton"])
        return element.exists
    }
}
