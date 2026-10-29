import SwiftUI

struct RootView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(AppTab.dashboard)
            LogWorkoutView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(AppTab.log)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.history)
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.progress)
        }
    }
}
