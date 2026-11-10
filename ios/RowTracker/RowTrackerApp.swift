import SwiftUI

@main
struct RowTrackerApp: App {
    @State private var router = AppRouter()
    @State private var store: WorkoutStore = {
        do {
            #if DEBUG
            // UI tests launch with -uiTesting so they get a fresh, seeded
            // in-memory database and never touch the simulator's real one.
            let db = ProcessInfo.processInfo.arguments.contains("-uiTesting")
                ? try AppDatabase.inMemory()
                : try AppDatabase.onDisk()
            #else
            let db = try AppDatabase.onDisk()
            #endif
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
