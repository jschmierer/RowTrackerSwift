import Foundation
import Testing
@testable import RowTracker

@Suite("IntervalFormRow derivation")
struct IntervalFormRowTests {
    @Test("Timed + split derives distance")
    func timedWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        row.secondaryStr = "1:40"
        let interval = try row.derive(kind: .timed)
        #expect(interval.durationSec == 300)
        // 300s @ 1:40/500m = 300/100 * 500 = 1500m
        #expect(interval.distanceMeters == 1500)
    }

    @Test("Timed + distance stores both as-is")
    func timedWithDistance() throws {
        var row = IntervalFormRow()
        row.primaryStr = "20:00"
        row.secondary = .otherQuantity
        row.secondaryStr = "5000"
        let interval = try row.derive(kind: .timed)
        #expect(interval.durationSec == 1200)
        #expect(interval.distanceMeters == 5000)
    }

    @Test("Distance + split derives time")
    func distanceWithSplit() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondary = .split
        row.secondaryStr = "1:50"
        let interval = try row.derive(kind: .distance)
        #expect(interval.distanceMeters == 2000)
        // 2000m @ 1:50/500m: time = 110 * (2000/500) = 110 * 4 = 440s
        #expect(interval.durationSec == 440)
    }

    @Test("Distance + time stores both as-is")
    func distanceWithTime() throws {
        var row = IntervalFormRow()
        row.primaryStr = "2000"
        row.secondary = .otherQuantity
        row.secondaryStr = "7:48"
        let interval = try row.derive(kind: .distance)
        #expect(interval.distanceMeters == 2000)
        #expect(interval.durationSec == 468)
    }

    @Test("Missing primary throws")
    func missingPrimary() {
        var row = IntervalFormRow()
        row.secondary = .split
        row.secondaryStr = "1:40"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Missing secondary throws")
    func missingSecondary() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Zero split rejected")
    func zeroSplit() {
        var row = IntervalFormRow()
        row.primaryStr = "5:00"
        row.secondary = .split
        row.secondaryStr = "0:00"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .timed)
        }
    }

    @Test("Garbage distance in distance workout rejected")
    func badDistance() {
        var row = IntervalFormRow()
        row.primaryStr = "banana"
        row.secondary = .split
        row.secondaryStr = "1:50"
        #expect(throws: IntervalFormRow.DeriveError.self) {
            _ = try row.derive(kind: .distance)
        }
    }
}
