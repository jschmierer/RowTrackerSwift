import SwiftUI

/// The read-only workout detail ("Workout Finished") screen. Reached from
/// History, the Dashboard, and the "Saved" sheet after logging. Layout
/// follows docs/mockups/workout-finished-page.png, top to bottom.
struct WorkoutDetailView: View {
    let workout: Workout
    /// "Saved" in the sheet shown right after logging, "Workout" otherwise.
    var navigationTitle = "Workout"

    /// Split | Watts toggle; starts on Split.
    @State private var pace: PaceMode = .split

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

            // Header: always these four, a dash when missing.
            Section {
                LabeledContent("Date", value: Self.dateFormatter.string(from: workout.date))
                LabeledContent("Average HR", value: DetailFormat.heartRate(workout.avgHR))
                    .accessibilityIdentifier("headerAvgHR")
                LabeledContent("Max HR", value: DetailFormat.heartRate(workout.maxHR))
                    .accessibilityIdentifier("headerMaxHR")
                LabeledContent("Effort", value: DetailFormat.effort(workout.effort))
                    .accessibilityIdentifier("headerEffort")
            }

            // Not in the mockup, but the rower typed them: keep them
            // visible just below the header.
            if workout.kind == .custom, let details = workout.details {
                Section("Details") {
                    Text(details)
                }
            }
            if !workout.notes.isEmpty {
                Section("Notes") {
                    Text(workout.notes)
                }
            }

            if workout.kind != .custom {
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
        // One switch for every pace value on the screen.
        Section {
            Picker("Show pace as", selection: $pace) {
                ForEach(PaceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("paceToggle")
        }

        Section("Totals") {
            LabeledContent("Total distance", value: DetailFormat.distance(workout.totalDistance))
            LabeledContent("Total time", value: DetailFormat.time(workout.totalDuration))
            LabeledContent(pace.averageLabel) {
                Text(pace.format(split: workout.averageSplit))
                    .accessibilityIdentifier("overallPace")
            }
        }

        Section(workout.intervals.count == 1 ? "Interval" : "Intervals") {
            ForEach(Array(workout.intervals.enumerated()), id: \.element.id) { pair in
                IntervalDetailRow(index: pair.offset, interval: pair.element, pace: pace)
            }
        }
    }
}

/// One interval: time, distance, split or watts, rate, and the rest after it.
struct IntervalDetailRow: View {
    let index: Int
    let interval: Interval
    let pace: PaceMode
    /// Prefix for accessibility identifiers, so the same row can appear in
    /// this workout's list and in the comparison lists.
    var idPrefix = "interval"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interval \(index + 1)")
                .font(.subheadline)
                .fontWeight(.medium)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    statColumn("Time", value: DetailFormat.time(interval.durationSec))
                    statColumn("Distance", value: DetailFormat.distance(interval.distanceMeters))
                    statColumn(pace.label, value: pace.format(split: interval.splitSec))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("\(idPrefix)Pace.\(index + 1)")
                }
                GridRow {
                    statColumn("Rate", value: DetailFormat.strokeRate(interval.strokeRate))
                    if let rest = interval.restSec {
                        statColumn("Rest after", value: DetailFormat.rest(rest))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("\(idPrefix)Rest.\(index + 1)")
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
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
