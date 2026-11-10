import Foundation
import Testing
@testable import RowTracker

@Suite("PaceMode (Split | Watts)")
struct PaceModeTests {
    @Test("formats a split as split or watts")
    func format() {
        #expect(PaceMode.split.format(split: 120) == "2:00.0 /500m")
        #expect(PaceMode.watts.format(split: 120) == "203 W")
        #expect(PaceMode.split.format(split: nil) == "—")
        #expect(PaceMode.watts.format(split: nil) == "—")
        #expect(PaceMode.split.averageLabel == "Average split")
        #expect(PaceMode.watts.averageLabel == "Average watts")
    }

    @Test("chart value is the split, or watts derived from it")
    func value() throws {
        #expect(PaceMode.split.value(split: 105) == 105)
        let w = try #require(PaceMode.watts.value(split: 105))
        #expect(abs(w - 302.3) < 0.1)
    }
}
