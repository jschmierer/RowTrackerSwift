import XCTest

/// Shared setup and helpers for UI tests. Launches the app with
/// -uiTesting (fresh, seeded in-memory database) on the Log tab.
class RowTrackerUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func openLogTab() {
        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Log Workout"].waitForExistence(timeout: 5))
    }

    /// Any element by accessibility identifier, whatever its type.
    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func selectWorkoutType(_ name: String) {
        let button = scrollTo(app.segmentedControls["workoutTypePicker"].buttons[name])
        button.tap()
        XCTAssertTrue(button.isSelected, "\(name) should be selected")
    }

    func tapSave() {
        dismissKeyboard()
        app.navigationBars["Log Workout"].buttons["Save"].tap()
    }

    func tapButton(_ id: String) {
        dismissKeyboard()
        let button = scrollTo(app.buttons[id])
        XCTAssertTrue(button.isHittable, "\(id) should be on screen")
        button.tap()
    }

    func setToggle(_ id: String, on: Bool) {
        dismissKeyboard()
        let toggle = scrollTo(app.switches[id])
        XCTAssertTrue(toggle.exists, "\(id) missing")
        guard isOn(toggle) != on else { return }
        toggle.switches.firstMatch.tap()
        let flipped = NSPredicate { _, _ in self.isOn(toggle) == on }
        let result = XCTWaiter.wait(for: [expectation(for: flipped, evaluatedWith: nil)],
                                    timeout: 2)
        XCTAssertEqual(result, .completed, "\(id) did not turn \(on ? "on" : "off")")
    }

    func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    func type(_ text: String, into id: String) {
        dismissKeyboard()
        let field = scrollTo(element(id))
        XCTAssertTrue(field.exists, "\(id) missing")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3),
                      "Keyboard didn't appear for \(id)")
        field.typeText(text)
    }

    func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.toolbars.buttons["Done"]
        if done.exists { done.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    /// Swipes until the element is on screen and below the navigation bar
    /// (or gives up). Lazy list rows don't exist until scrolled to, so when
    /// it isn't there yet this tries downwards first, then upwards.
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 10) -> XCUIElement {
        _ = element.waitForExistence(timeout: 1)
        var swipes = 0
        var goingUp = true
        while !isVisible(element) && swipes < maxSwipes {
            if element.exists {
                let navBottom = app.navigationBars.firstMatch.frame.maxY
                if element.frame.minY < navBottom + 10 {
                    app.swipeDown(velocity: .slow)
                } else {
                    app.swipeUp(velocity: .slow)
                }
            } else {
                if goingUp { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
                if swipes == maxSwipes / 2 { goingUp = false }
            }
            swipes += 1
        }
        return element
    }

    func isVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY
                                                   : app.windows.firstMatch.frame.maxY
        return element.frame.minY >= navBottom && element.frame.maxY <= tabTop
    }

    /// True once the element can be scrolled on screen.
    func appears(_ element: XCUIElement) -> Bool {
        scrollTo(element).exists
    }
}
