import Foundation
import Testing
@testable import RowTracker

@Suite("Share summary")
struct WorkoutShareTextTests {
    private let la = TimeZone(identifier: "America/Los_Angeles")!
    private let us = Locale(identifier: "en_US")
    /// Nov 9, 2026, noon in Los Angeles.
    private let date = Date(timeIntervalSince1970: 1_794_254_400)

    @Test("interval workout: title, date, overall stats, each interval with rest")
    func intervals() {
        let w = Workout(kind: .distance, date: date, notes: "felt strong",
                        intervals: [
                            Interval(durationSec: 100, distanceMeters: 500, strokeRate: 30, restSec: 60),
                            Interval(durationSec: 102, distanceMeters: 500, strokeRate: 29, restSec: 60),
                            Interval(durationSec: 98, distanceMeters: 500),
                        ],
                        avgHR: 160, maxHR: 182, effort: 8)
        let text = WorkoutShareText.make(for: w, locale: us, timeZone: la)
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "3x500m")
        #expect(lines[1] == "November 9, 2026")
        #expect(text.contains("Total time: 5:00.0"))
        #expect(text.contains("Total distance: 1500 m"))
        #expect(text.contains("Average split: 1:40.0 /500m"))
        #expect(text.contains("Average watts: 350 W"))
        #expect(text.contains("Average HR: 160 bpm"))
        #expect(text.contains("Max HR: 182 bpm"))
        #expect(text.contains("Effort: 8 / 10"))
        #expect(text.contains("1. 1:40.0 · 500 m · 1:40.0 /500m · 350 W · 30 spm"))
        #expect(text.contains("3. 1:38.0 · 500 m"))
        // Rest after intervals 1 and 2, not after the last; not in the total.
        #expect(text.components(separatedBy: "Rest 1:00").count - 1 == 2)
        #expect(text.hasSuffix("Notes: felt strong"))
    }

    @Test("single piece: no interval list")
    func singlePiece() {
        let w = Workout(kind: .timed, date: date,
                        intervals: [Interval(durationSec: 1800, distanceMeters: 7500)])
        let text = WorkoutShareText.make(for: w, locale: us, timeZone: la)
        #expect(text.hasPrefix("30:00\n"))
        #expect(!text.contains("Intervals:"))
        #expect(!text.contains("Average HR"))
    }

    @Test("custom workout: title, date, details, no rowing stats")
    func custom() {
        let w = Workout(kind: .custom, date: date, effort: 5,
                        title: "Bike 30 min", details: "Zone 2\nCadence 90")
        let text = WorkoutShareText.make(for: w, locale: us, timeZone: la)
        #expect(text.hasPrefix("Bike 30 min\nNovember 9, 2026\n\nZone 2\nCadence 90"))
        #expect(!text.contains("split"))
        #expect(!text.contains("Total distance"))
        #expect(text.contains("Effort: 5 / 10"))
    }

    @Test("detail times drop the leading zero")
    func timeFormat() {
        #expect(DetailFormat.time(300) == "5:00.0")
        #expect(DetailFormat.time(45) == "0:45.0")
        #expect(DetailFormat.time(1800) == "30:00.0")
        #expect(DetailFormat.time(3723.4) == "1:02:03.4")
    }
}
