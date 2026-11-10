import SwiftUI
import Charts

/// The read-only workout detail ("Workout Finished") screen. Reached from
/// History, the Dashboard, and the "Saved" sheet after logging. Layout
/// follows docs/mockups/workout-finished-page.png, top to bottom.
struct WorkoutDetailView: View {
    @Environment(WorkoutStore.self) private var store
    let workout: Workout
    /// "Saved" in the sheet shown right after logging, "Workout" otherwise.
    var navigationTitle = "Workout"

    /// Split | Watts toggle; starts on Split.
    @State private var pace: PaceMode = .split
    /// This workout's intervals start open; the comparison ones start closed.
    @State private var intervalsExpanded = true
    @State private var previousExpanded = false
    @State private var bestExpanded = false

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

        Section("Overall") {
            OverallRows(workout: workout, pace: pace, idPrefix: "overall")
        }

        // A single piece is fully described by Overall.
        if workout.intervals.count > 1 {
            Section {
                IntervalsDisclosure(intervals: workout.intervals,
                                    pace: pace,
                                    isExpanded: $intervalsExpanded,
                                    idPrefix: "interval")
            }
        }

        if let comparison = WorkoutComparison.make(for: workout, among: store.workouts) {
            comparisonSections(comparison)
        }
    }

    // MARK: - Comparison

    @ViewBuilder
    private func comparisonSections(_ c: WorkoutComparison) -> some View {
        comparedWorkout(c.previous, heading: "Previous", idPrefix: "previous",
                        expanded: $previousExpanded)
        if let best = c.best {
            comparedWorkout(best, heading: "Best", idPrefix: "best",
                            expanded: $bestExpanded)
        }
        Section {
            ComparisonChart(history: c.history, current: workout, pace: pace)
                .frame(height: 220)
                .padding(.vertical, 8)
                .accessibilityIdentifier("comparisonChart")
        } header: {
            Text("Every \(WorkoutTitle.make(for: workout))")
        } footer: {
            Text(pace == .split
                 ? "Average split of each one. Up is faster."
                 : "Average watts of each one. Up is faster.")
        }
    }

    @ViewBuilder
    private func comparedWorkout(_ other: Workout, heading: String, idPrefix: String,
                                 expanded: Binding<Bool>) -> some View {
        Section {
            OverallRows(workout: other, pace: pace, idPrefix: "\(idPrefix)Overall")
            if other.intervals.count > 1 {
                IntervalsDisclosure(intervals: other.intervals, pace: pace,
                                    isExpanded: expanded,
                                    idPrefix: "\(idPrefix)Interval")
            }
        } header: {
            // e.g. "Comparison: Previous · Nov 2, 2026"
            Text("Comparison: \(heading) · \(Self.shortDate.string(from: other.date))")
                .accessibilityIdentifier("\(idPrefix)Header")
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

/// Every matching workout's average split (or watts) over time. Faster is
/// always higher: the split axis is flipped, watts aren't. This workout's
/// point is highlighted.
private struct ComparisonChart: View {
    let history: [Workout]
    let current: Workout
    let pace: PaceMode

    private struct Point: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
        let isCurrent: Bool
    }

    private var points: [Point] {
        history.compactMap { w in
            guard let split = w.averageSplit, let value = pace.value(split: split) else { return nil }
            return Point(id: w.id, date: w.date, value: value, isCurrent: w.id == current.id)
        }
    }

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value(pace.label, p.value))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", p.date), y: .value(pace.label, p.value))
                .foregroundStyle(p.isCurrent ? Color.orange : Color.accentColor)
                .symbolSize(p.isCurrent ? 120 : 40)
        }
        .chartYScale(domain: .automatic(includesZero: false, reversed: pace == .split))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(pace == .split ? DetailFormat.time(v) : "\(Int(v.rounded())) W")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}

/// Overall stats for a workout: total time, total distance, average split
/// (or watts), average rate. Rest is never included.
///
/// Average split = total time / total distance x 500. Average watts come
/// from that average split (not an average of each interval's watts).
/// Average rate is weighted by interval duration.
struct OverallRows: View {
    let workout: Workout
    let pace: PaceMode
    let idPrefix: String

    var body: some View {
        LabeledContent("Total time", value: DetailFormat.time(workout.totalDuration))
        LabeledContent("Total distance", value: DetailFormat.distance(workout.totalDistance))
        LabeledContent(pace.averageLabel) {
            Text(pace.format(split: workout.averageSplit))
                .accessibilityIdentifier("\(idPrefix)Pace")
        }
        LabeledContent("Average rate") {
            Text(DetailFormat.averageRate(workout.averageStrokeRate))
                .accessibilityIdentifier("\(idPrefix)Rate")
        }
    }
}

/// "Intervals (N)", tap to show or hide every interval.
struct IntervalsDisclosure: View {
    let intervals: [Interval]
    let pace: PaceMode
    @Binding var isExpanded: Bool
    let idPrefix: String

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(Array(intervals.enumerated()), id: \.element.id) { pair in
                IntervalDetailRow(index: pair.offset, interval: pair.element,
                                  pace: pace, idPrefix: idPrefix)
            }
        } label: {
            // Identifier on the label: on the group it would replace the
            // rows' own identifiers.
            Text("Intervals (\(intervals.count))")
                .fontWeight(.medium)
                .accessibilityIdentifier("\(idPrefix)sDisclosure")
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
