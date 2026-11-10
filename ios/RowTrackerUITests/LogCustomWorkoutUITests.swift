import XCTest

/// Logging a Custom workout: title and details only, title required.
final class LogCustomWorkoutUITests: RowTrackerUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openLogTab()
    }

    func testCustomHidesIntervalControls() {
        XCTAssertTrue(appears(app.switches["intervalsToggle"]))
        selectWorkoutType("Custom")

        XCTAssertTrue(appears(element("customTitleField")))
        XCTAssertTrue(appears(element("customDetailsField")))
        XCTAssertFalse(app.switches["intervalsToggle"].exists)
        XCTAssertFalse(element("secondaryField.1").exists)
        XCTAssertFalse(app.segmentedControls.buttons["Watts"].exists)
        // The always-present fields are still there.
        XCTAssertTrue(appears(app.switches["Record heart rate"]))
        XCTAssertTrue(appears(app.sliders.firstMatch))

        selectWorkoutType("Time")
        XCTAssertTrue(appears(app.switches["intervalsToggle"]))
        XCTAssertFalse(element("customTitleField").exists)
    }

    func testCustomWorkoutRequiresTitleThenSaves() {
        selectWorkoutType("Custom")
        tapSave()

        let error = element("customTitleError")
        XCTAssertTrue(appears(error), "A missing title should show a message")
        XCTAssertTrue(error.label.contains("Give your custom workout a title"))
        XCTAssertFalse(app.navigationBars["Saved"].exists)

        type("Bike 30 min", into: "customTitleField")
        type("Zone 2, cadence 90", into: "customDetailsField")
        tapSave()

        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))
        XCTAssertEqual(element("workoutTitle").label, "Bike 30 min")
        XCTAssertTrue(app.staticTexts["Zone 2, cadence 90"].exists)

        app.navigationBars["Saved"].buttons["Done"].tap()
        // Back on the Dashboard, the newest workout is the custom one.
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(appears(app.staticTexts["Bike 30 min"]))
    }
}
