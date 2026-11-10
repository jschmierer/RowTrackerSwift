import SwiftUI

/// The read-only workout detail screen. Reached from the History list and
/// from the "just saved" sheet in the Log flow.
struct WorkoutDetailView: View {
    let workout: Workout
    /// "Saved" in the sheet shown right after logging, "Workout" otherwise.
    var navigationTitle = "Workout"

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        List {
            Section {
                Text(WorkoutTitle.make(for: workout))
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("workoutTitle")
            }

            Section("Workout") {
                LabeledContent("Date", value: Self.dateFormatter.string(from: workout.date))
                LabeledContent("Type", value: workout.kind.displayName)
                LabeledContent("Average HR", value: DetailFormat.heartRate(workout.avgHR))
                LabeledContent("Max HR", value: DetailFormat.heartRate(workout.maxHR))
                LabeledContent("Effort", value: DetailFormat.effort(workout.effort))
                if !workout.notes.isEmpty {
                    LabeledContent("Notes") {
                        Text(workout.notes)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            if workout.kind == .custom {
                if let details = workout.details {
                    Section("Details") {
                        Text(details)
                    }
                }
            } else {
                rowedSections
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: WorkoutShareText.make(for: workout),
                          subject: Text(WorkoutTitle.make(for: workout)),
                          preview: SharePreview(WorkoutTitle.make(for: workout))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shareButton")
            }
        }
    }

    @ViewBuilder
    private var rowedSections: some View {
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
            // Two rows of three so five stats fit on a phone without
            // squeezing the split.
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    statColumn("Time", value: RowingMath.formatTime(interval.durationSec))
                    statColumn("Distance",
                               value: interval.distanceMeters.map {
                                   WorkoutDetailView.distanceString($0)
                               } ?? DetailFormat.missing)
                    statColumn("Split",
                               value: interval.splitSec.map {
                                   RowingMath.formatTime($0) + " /500m"
                               } ?? DetailFormat.missing)
                }
                GridRow {
                    statColumn("Watts", value: DetailFormat.watts(interval.watts))
                    statColumn("Rate",
                               value: interval.strokeRate.map { "\($0) spm" }
                                   ?? DetailFormat.missing)
                    if let rest = interval.restSec {
                        statColumn("Rest", value: RowingMath.formatTime(rest))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("intervalRest.\(index + 1)")
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
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
