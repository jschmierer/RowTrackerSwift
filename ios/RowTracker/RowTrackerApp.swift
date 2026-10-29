import SwiftUI

@main
struct RowTrackerApp: App {
    @State private var router = AppRouter()
    @State private var store: WorkoutStore = {
        do {
            let db = try AppDatabase.onDisk()
            let repo = WorkoutRepository(db)
            let store = WorkoutStore(repository: repo)
            #if DEBUG
            // Debug builds seed sample workouts so Dashboard and Progress
            // aren't empty when developing. Release builds (TestFlight, App
            // Store) start with a clean database.
            store.seedIfEmpty(with: SampleData.seedWorkouts())
            #endif
            return store
        } catch {
            fatalError("Could not open database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
        }
    }
}
