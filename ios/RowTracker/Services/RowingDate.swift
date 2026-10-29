import Foundation

/// Day-level helpers that never cross a timezone boundary.
///
/// A rower logging a workout at 11:30 PM in California shouldn't see the
/// workout filed under the next day because UTC rolled over. These helpers
/// always decompose the date in a specific calendar (defaulting to the
/// user's current calendar), never in UTC.
enum RowingDate {
    /// Returns the day the given `Date` falls on, formatted "YYYY-MM-DD",
    /// using the supplied calendar's time zone.
    static func localDateString(from date: Date,
                                calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Normalizes the given `Date` to midnight at the start of its local day,
    /// so persisted workout dates don't drift under a different time zone.
    static func startOfLocalDay(for date: Date,
                                calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}
