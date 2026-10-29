import Foundation
import Testing
@testable import RowTracker

@Suite("RowingDate.localDateString")
struct RowingDateTests {
    private func california() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    @Test("Late-night California stays on today's local date, not UTC's tomorrow")
    func lateNightCalifornia() {
        // 11:30 PM PDT on 2026-07-04 is 06:30 UTC on 2026-07-05. A naive
        // ISO-8601 UTC format would file the workout as 2026-07-05 — this
        // test asserts the local-day string is 2026-07-04.
        let cal = california()
        let late = cal.date(from: DateComponents(year: 2026, month: 7, day: 4,
                                                 hour: 23, minute: 30))!
        #expect(RowingDate.localDateString(from: late, calendar: cal) == "2026-07-04")
    }

    @Test("Just after midnight local is already the next day")
    func justAfterMidnight() {
        let cal = california()
        let justAfter = cal.date(from: DateComponents(year: 2026, month: 7, day: 5,
                                                      hour: 0, minute: 15))!
        #expect(RowingDate.localDateString(from: justAfter, calendar: cal) == "2026-07-05")
    }

    @Test("Single-digit month and day are zero-padded")
    func pads() {
        let cal = california()
        let d = cal.date(from: DateComponents(year: 2026, month: 3, day: 9,
                                              hour: 12))!
        #expect(RowingDate.localDateString(from: d, calendar: cal) == "2026-03-09")
    }

    @Test("startOfLocalDay rolls to local midnight, regardless of the input time")
    func startOfLocalDay() {
        let cal = california()
        let afternoon = cal.date(from: DateComponents(year: 2026, month: 7, day: 4,
                                                      hour: 14, minute: 30))!
        let midnight = RowingDate.startOfLocalDay(for: afternoon, calendar: cal)
        let roundTrip = cal.dateComponents([.year, .month, .day, .hour, .minute], from: midnight)
        #expect(roundTrip.year == 2026)
        #expect(roundTrip.month == 7)
        #expect(roundTrip.day == 4)
        #expect(roundTrip.hour == 0)
        #expect(roundTrip.minute == 0)
    }
}
