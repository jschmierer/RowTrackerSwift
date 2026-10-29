import SwiftUI

/// The read-only workout detail screen. Reached from the History list and
/// from the "just saved" sheet in the Log flow.
struct WorkoutDetailView: View {
    let workout: Workout

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        List {
            Section("Workout") {
                LabeledContent("Date", value: Self.dateFormatter.string(from: workout.date))
                LabeledContent("Type",
                               value: workout.kind == .timed ? "Timed" : "Distance")
                if !workout.notes.isEmpty {
                    LabeledContent("Notes") {
                        Text(workout.notes)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Totals") {
                LabeledContent("Total distance",
                               value: Self.distanceString(workout.totalDistance))
                LabeledContent("Total time",
                               value: RowingMath.formatTime(workout.totalDuration))
                LabeledContent("Average split",
                               value: workout.averageSplit.map {
                                   RowingMath.formatTime($0) + " /500m"
                               } ?? "—")
            }

            Section(workout.intervals.count == 1 ? "Interval" : "Intervals") {
                ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { pair in
                    IntervalDetailRow(index: pair.offset, interval: pair.element)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func distanceString(_ meters: Double) -> String {
        if meters >= 10000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }
}

private struct IntervalDetailRow: View {
    let index: Int
    let interval: Interval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interval \(index + 1)")
                .font(.subheadline)
                .fontWeight(.medium)
            HStack(alignment: .top) {
                statColumn("Time", value: RowingMath.formatTime(interval.durationSec))
                statColumn("Distance",
                           value: interval.distanceMeters.map {
                               WorkoutDetailView.distanceString($0)
                           } ?? "—")
                statColumn("Split",
                           value: interval.splitSec.map {
                               RowingMath.formatTime($0) + " /500m"
                           } ?? "—")
                statColumn("Rate",
                           value: interval.strokeRate.map { "\($0) spm" } ?? "—")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statColumn(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
