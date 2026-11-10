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

    /// Opens the newest workout with this title from History (newest first).
    func openFromHistory(_ title: String) {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        let row = scrollTo(app.staticTexts.matching(identifier: title).firstMatch)
        XCTAssertTrue(row.exists, "No \(title) in History")
        row.tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        XCTAssertEqual(element("workoutTitle").label, title)
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

        // One piece: no Intervals section.
        XCTAssertFalse(element("intervalsDisclosure").exists)
    }

    func testIntervalsExpandAndFollowTheToggle() {
        openFromHistory("3x8:00")

        let first = scrollTo(element("intervalPace.1"))
        XCTAssertTrue(first.exists, "Intervals start expanded")
        XCTAssertTrue(first.label.hasSuffix("/500m"))
        XCTAssertTrue(appears(element("intervalPace.3")))

        selectPace("Watts")
        XCTAssertTrue(scrollTo(element("intervalPace.1")).label.hasSuffix(" W"))

        // Collapse, then expand again.
        let disclosure = scrollTo(app.buttons["Intervals (3)"])
        disclosure.tap()
        XCTAssertTrue(element("intervalPace.1").waitForNonExistence(timeout: 3))
        scrollTo(app.buttons["Intervals (3)"]).tap()
        XCTAssertTrue(appears(element("intervalPace.1")))
    }

    func testSplitWattsToggleFromHistory() {
        openFromHistory("3x8:00")

        let split = overallPace()
        XCTAssertTrue(split.hasSuffix("/500m"), "Starts on Split: \(split)")

        selectPace("Watts")
        XCTAssertTrue(overallPace().hasSuffix(" W"))
    }

    // MARK: - Comparison

    func testComparisonShowsPreviousBestAndGraph() {
        // Seeded 2000m pieces: 8:12, 8:00, 7:55, then 7:48 (newest).
        openFromHistory("2000m")

        // Previous (7:55) is also the best earlier one: both are shown.
        XCTAssertTrue(appears(element("previousHeader")))
        XCTAssertEqual(scrollTo(element("previousOverallPace")).label,
                       "Average split, 1:58.8 /500m")
        XCTAssertTrue(appears(element("bestHeader")))
        XCTAssertEqual(scrollTo(element("bestOverallPace")).label,
                       "Average split, 1:58.8 /500m")
        XCTAssertTrue(appears(element("comparisonChart")))

        // The toggle switches the comparison values too.
        selectPace("Watts")
        XCTAssertTrue(scrollTo(element("previousOverallPace")).label.hasSuffix(" W"))
        XCTAssertTrue(scrollTo(element("bestOverallPace")).label.hasSuffix(" W"))
    }

    func testNoComparisonWithoutAnEarlierMatch() {
        // The only 3x8:00 in the seed data.
        openFromHistory("3x8:00")
        for _ in 0..<4 { app.swipeUp(velocity: .fast) }
        XCTAssertFalse(element("previousHeader").exists)
        XCTAssertFalse(element("comparisonChart").exists)
    }
}
