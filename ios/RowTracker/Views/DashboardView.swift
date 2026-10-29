import SwiftUI

struct DashboardView: View {
    @Environment(WorkoutStore.self) private var store

    private var thisWeekMeters: Double {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return store.workouts
            .filter { $0.date >= start }
            .map(\.totalDistance)
            .reduce(0, +)
    }

    private var totalMeters: Double {
        store.workouts.map(\.totalDistance).reduce(0, +)
    }

    private var recent: [Workout] {
        Array(store.workouts.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Total meters",
                                 value: Self.meterString(totalMeters))
                        StatTile(title: "This week",
                                 value: Self.meterString(thisWeekMeters))
                        StatTile(title: "Workouts",
                                 value: "\(store.workouts.count)")
                        StatTile(title: "Best 2k",
                                 value: bestTwoK)
                    }

                    if !recent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent workouts")
                                .font(.headline)
                            ForEach(recent) { w in
                                NavigationLink(value: w) {
                                    WorkoutRow(workout: w)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ContentUnavailableView(
                            "No workouts yet",
                            systemImage: "oar.2.crossed",
                            description: Text("Log your first workout from the Log tab.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Dashboard")
            .navigationDestination(for: Workout.self) { w in
                WorkoutDetailView(workout: w)
            }
        }
    }

    private static func meterString(_ m: Double) -> String {
        if m >= 10000 {
            return String(format: "%.1f km", m / 1000)
        }
        return "\(Int(m)) m"
    }

    private var bestTwoK: String {
        let candidates = store.workouts.filter { workout in
            // Treat a single-interval workout at ~2000m as a 2k test.
            workout.intervals.count == 1
                && (1950...2050).contains(workout.intervals[0].distanceMeters ?? 0)
        }
        let fastest = candidates.min { ($0.totalDuration) < ($1.totalDuration) }
        guard let fastest else { return "—" }
        return RowingMath.formatTime(fastest.totalDuration)
    }
}
