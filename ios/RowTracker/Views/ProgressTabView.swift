import SwiftUI
import Charts

struct ProgressTabView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var selectedGroupKey: WorkoutGroupKey?

    private var groups: [WorkoutGroup] {
        WorkoutGrouping.groups(from: store.workouts)
    }

    /// Currently selected group — defaults to the group with the most
    /// workouts (first in the sorted list). Falls back when the previous
    /// selection has disappeared (e.g. after a delete).
    private var activeGroup: WorkoutGroup? {
        if let key = selectedGroupKey,
           let match = groups.first(where: { $0.key == key }) {
            return match
        }
        return groups.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    splitCard
                    weeklyMetersCard
                }
                .padding(16)
            }
            .navigationTitle("Progress")
        }
    }

    // MARK: - Split card

    @ViewBuilder
    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average split over time")
                .font(.headline)
            Text("Compare like with like: pick a group of comparable workouts. Up means faster.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if groups.isEmpty {
                emptyChart
            } else {
                groupPicker
                if let group = activeGroup {
                    splitChart(for: group)
                } else {
                    emptyChart
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var groupPicker: some View {
        Picker("Group", selection: Binding(
            get: { activeGroup?.key },
            set: { selectedGroupKey = $0 }
        )) {
            ForEach(groups) { group in
                Text("\(group.key.label)  ·  \(group.workouts.count)")
                    .tag(Optional(group.key))
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private func splitChart(for group: WorkoutGroup) -> some View {
        let points: [SplitPoint] = group.workouts.compactMap { w in
            guard let avg = w.averageSplit else { return nil }
            return SplitPoint(id: w.id, date: w.date, splitSec: avg)
        }
        if points.isEmpty {
            emptyChart
        } else {
            Chart(points) { p in
                LineMark(x: .value("Date", p.date),
                         y: .value("Split", p.splitSec))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", p.date),
                          y: .value("Split", p.splitSec))
            }
            // Flipped: faster (smaller) splits are higher on the chart.
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(RowingMath.formatTime(seconds))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }

    // MARK: - Weekly meters card (unchanged)

    @ViewBuilder
    private var weeklyMetersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly meters")
                .font(.headline)
            if weeklyPoints.isEmpty {
                emptyChart
            } else {
                Chart(weeklyPoints) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Meters", week.meters)
                    )
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var weeklyPoints: [WeekPoint] {
        let calendar = Calendar.current
        var buckets: [Date: Double] = [:]
        for w in store.workouts {
            let week = calendar.dateInterval(of: .weekOfYear, for: w.date)?.start ?? w.date
            buckets[week, default: 0] += w.totalDistance
        }
        return buckets
            .map { WeekPoint(weekStart: $0.key, meters: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    @ViewBuilder
    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Log a few workouts of the same shape to see progress here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct SplitPoint: Identifiable {
    let id: UUID
    let date: Date
    let splitSec: TimeInterval
}

private struct WeekPoint: Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let meters: Double
}
