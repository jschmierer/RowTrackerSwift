import SwiftUI

@main
struct RowTrackerApp: App {
    @State private var store: WorkoutStore = {
        do {
            let db = try AppDatabase.onDisk()
            let repo = WorkoutRepository(db)
            let store = WorkoutStore(repository: repo)
            store.seedIfEmpty(with: SampleData.seedWorkouts())
            return store
        } catch {
            fatalError("Could not open database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
