import Foundation
import Testing
@testable import RowTracker

@Suite("Detail screen formatting")
struct DetailFormatTests {
    @Test("Missing values show a dash")
    func dashes() {
        let old = Workout(kind: .timed, intervals: [Interval(durationSec: 30)])
        #expect(DetailFormat.heartRate(old.avgHR) == "—")
        #expect(DetailFormat.heartRate(old.maxHR) == "—")
        #expect(DetailFormat.effort(old.effort) == "—")
        #expect(DetailFormat.watts(old.intervals[0].watts) == "—",
                "no distance -> no split -> no watts")
    }

    @Test("Present values are formatted")
    func values() {
        #expect(DetailFormat.heartRate(152) == "152 bpm")
        #expect(DetailFormat.effort(0) == "0 / 10")
        #expect(DetailFormat.effort(10) == "10 / 10")
    }

    @Test("Interval watts are derived from its split")
    func intervalWatts() {
        // 500 m in 2:00.0 -> 2:00.0 split -> ~202.5 W
        let i = Interval(durationSec: 120, distanceMeters: 500)
        #expect(DetailFormat.watts(i.watts) == "203 W")
    }
}
