import XCTest

/// The Workout Finished (detail) screen: opened after saving and from
/// History, and its Split | Watts toggle.
final class WorkoutDetailUITests: RowTrackerUITestCase {
    /// Logs a single 2000m piece at a 2:00.0 split and lands on "Saved".
    private func logTwoK() {
        openLogTab()
        selectWorkoutType("Distance")
        type("2000", into: "primaryField.1")
        type("2:00", into: "secondaryField.1")
        tapSave()
        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))
    }

    private func selectPace(_ name: String) {
        let button = scrollTo(app.segmentedControls["paceToggle"].buttons[name])
        XCTAssertTrue(button.exists, "Pace toggle missing")
        button.tap()
        XCTAssertTrue(button.isSelected)
    }

    /// The overall average row, read as VoiceOver reads it
    /// ("Average split, 2:00.0 /500m").
    private func overallPace() -> String {
        scrollTo(element("overallPace")).label
    }

    func testSplitWattsToggleAfterSaving() {
        logTwoK()
        XCTAssertEqual(element("workoutTitle").label, "2000m")
        XCTAssertTrue(element("shareButton").exists)

        XCTAssertEqual(overallPace(), "Average split, 2:00.0 /500m")

        selectPace("Watts")
        // 2:00.0 /500m is 202.5 W.
        XCTAssertEqual(overallPace(), "Average watts, 203 W")

        selectPace("Split")
        XCTAssertEqual(overallPace(), "Average split, 2:00.0 /500m")
    }

    func testSplitWattsToggleFromHistory() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        // Newest seeded workout: 3x8:00.
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))

        let split = overallPace()
        XCTAssertTrue(split.hasSuffix("/500m"), "Starts on Split: \(split)")

        selectPace("Watts")
        XCTAssertTrue(overallPace().hasSuffix(" W"))
    }
}
