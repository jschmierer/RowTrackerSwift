import XCTest

/// Rest between intervals on the Log Workout screen, with Variable rest
/// off (one shared value) and on (a value after each interval).
final class LogRestUITests: RowTrackerUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openLogTab()
    }

    func testSharedRestWhenVariableRestOff() {
        setToggle("intervalsToggle", on: true)

        let variableRest = scrollTo(app.switches["variableRestToggle"])
        XCTAssertTrue(variableRest.exists)
        XCTAssertFalse(isOn(variableRest), "Variable rest defaults off for shared intervals")
        XCTAssertTrue(appears(element("sharedRestField")))
        XCTAssertFalse(element("restField.1").exists)

        // Time workout: 2 x 5:00 at 2:00 and 1:58, 1:00 rest.
        type("5:00", into: "sharedPrimaryField")
        type("1:00", into: "sharedRestField")
        type("2:00", into: "secondaryField.1")
        type("1:58", into: "secondaryField.2")
        tapSave()

        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))
        // Rest after interval 1, none after the last.
        XCTAssertTrue(appears(element("intervalRest.1")))
        XCTAssertTrue(element("intervalRest.1").label.contains("1:00"))
        XCTAssertFalse(element("intervalRest.2").exists)
    }

    func testRestAfterEachIntervalWhenVariableRestOn() {
        setToggle("intervalsToggle", on: true)
        setToggle("variableToggle", on: true)

        let variableRest = scrollTo(app.switches["variableRestToggle"])
        XCTAssertTrue(isOn(variableRest), "Variable rest defaults on for variable intervals")
        XCTAssertFalse(element("sharedRestField").exists)
        XCTAssertTrue(appears(element("restField.1")))
        XCTAssertFalse(element("restField.2").exists, "No rest after the last interval")

        tapButton("addIntervalButton")
        XCTAssertTrue(appears(element("restField.2")))
        XCTAssertFalse(element("restField.3").exists)

        // Time workout: 5:00 / 4:00 / 3:00 with 2:00 and 1:30 rest.
        type("5:00", into: "primaryField.1")
        type("2:00", into: "secondaryField.1")
        type("2:00", into: "restField.1")
        type("4:00", into: "primaryField.2")
        type("1:58", into: "secondaryField.2")
        type("1:30", into: "restField.2")
        type("3:00", into: "primaryField.3")
        type("1:55", into: "secondaryField.3")
        tapSave()

        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(appears(element("intervalRest.1")))
        XCTAssertTrue(element("intervalRest.1").label.contains("2:00"))
        XCTAssertTrue(appears(element("intervalRest.2")))
        XCTAssertTrue(element("intervalRest.2").label.contains("1:30"))
        XCTAssertFalse(element("intervalRest.3").exists)
    }

    func testTurningVariableRestOnInSharedLayout() {
        setToggle("intervalsToggle", on: true)
        XCTAssertTrue(appears(element("sharedRestField")))

        setToggle("variableRestToggle", on: true)
        XCTAssertTrue(appears(element("restField.1")))
        XCTAssertFalse(element("sharedRestField").exists)

        setToggle("variableRestToggle", on: false)
        XCTAssertTrue(appears(element("sharedRestField")))
        XCTAssertFalse(element("restField.1").exists)
    }
}
