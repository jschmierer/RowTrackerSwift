import SwiftUI

struct RootView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            LogWorkoutView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
        }
    }
}
