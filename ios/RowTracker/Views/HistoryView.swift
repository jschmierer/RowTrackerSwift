import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Workouts you log will appear here.")
                    )
                } else {
                    List {
                        ForEach(store.workouts) { w in
                            WorkoutRow(workout: w)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
            .alert("Could not delete",
                   isPresented: Binding(get: { deletionError != nil },
                                        set: { if !$0 { deletionError = nil } })) {
                Button("OK") { deletionError = nil }
            } message: {
                Text(deletionError ?? "")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let workout = store.workouts[index]
            do {
                try store.delete(workout)
            } catch {
                deletionError = error.localizedDescription
            }
        }
    }
}
