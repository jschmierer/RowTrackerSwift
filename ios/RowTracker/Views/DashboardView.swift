import SwiftUI

struct DashboardView: View {
    @Environment(WorkoutStore.self) private var store

    private var thisWeekMeters: Double {
        WorkoutStats.thisWeekMeters(store.workouts)
    }

    private var totalMeters: Double {
        WorkoutStats.totalMeters(store.workouts)
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
        WorkoutStats.bestTwoK(store.workouts).map(RowingMath.formatTime) ?? "—"
    }
}
