import Foundation

/// The plain-text summary handed to the iOS share sheet: title, date,
/// overall stats, then each interval.
enum WorkoutShareText {
    static func make(for workout: Workout,
                     locale: Locale = .current,
                     timeZone: TimeZone = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        var lines: [String] = [
            WorkoutTitle.make(for: workout),
            dateFormatter.string(from: workout.date),
            "",
        ]

        if workout.kind == .custom {
            if let details = workout.details {
                lines.append(details)
                lines.append("")
            }
        } else {
            lines.append("Total time: \(DetailFormat.time(workout.totalDuration))")
            lines.append("Total distance: \(DetailFormat.distance(workout.totalDistance))")
            lines.append("Average split: \(DetailFormat.split(workout.averageSplit))")
            lines.append("Average watts: \(DetailFormat.watts(workout.averageSplit.flatMap(RowingMath.watts(fromSplit:))))")
        }

        if workout.avgHR != nil || workout.maxHR != nil {
            lines.append("Average HR: \(DetailFormat.heartRate(workout.avgHR))")
            lines.append("Max HR: \(DetailFormat.heartRate(workout.maxHR))")
        }
        if let effort = workout.effort {
            lines.append("Effort: \(DetailFormat.effort(effort))")
        }

        if workout.intervals.count > 1 {
            lines.append("")
            lines.append("Intervals:")
            for (i, interval) in workout.intervals.enumerated() {
                var parts = [
                    DetailFormat.time(interval.durationSec),
                    DetailFormat.distance(interval.distanceMeters),
                    DetailFormat.split(interval.splitSec),
                    DetailFormat.watts(interval.watts),
                ]
                if let rate = interval.strokeRate { parts.append("\(rate) spm") }
                lines.append("\(i + 1). " + parts.joined(separator: " · "))
                if let rest = interval.restSec {
                    lines.append("   Rest \(DetailFormat.rest(rest))")
                }
            }
        }

        if !workout.notes.isEmpty {
            lines.append("")
            lines.append("Notes: \(workout.notes)")
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
