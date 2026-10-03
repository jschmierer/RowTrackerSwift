import SwiftUI
import Charts

struct ProgressTabView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    averageSplitCard
                    weeklyMetersCard
                }
                .padding(16)
            }
            .navigationTitle("Progress")
        }
    }

    private var splitPoints: [SplitPoint] {
        store.workouts
            .compactMap { w -> SplitPoint? in
                guard let avg = w.averageSplit, avg > 0 else { return nil }
                return SplitPoint(id: w.id, date: w.date, splitSec: avg)
            }
            .sorted { $0.date < $1.date }
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
    private var averageSplitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average split over time")
                .font(.headline)
            Text("Lower is faster — the y-axis is flipped so up means faster.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if splitPoints.isEmpty {
                emptyChart
            } else {
                Chart(splitPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Split", point.splitSec)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Split", point.splitSec)
                    )
                }
                // Flip the y-axis so faster splits (smaller numbers) appear higher.
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
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

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

    @ViewBuilder
    private var emptyChart: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Log a workout to see your progress here.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
