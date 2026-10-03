import Foundation
import Observation

/// Observable facade over `WorkoutRepository`. Views read `workouts` and call
/// `save` / `delete`; the store refreshes its snapshot after each write.
@MainActor
@Observable
final class WorkoutStore {
    let repository: WorkoutRepository
    private(set) var workouts: [Workout] = []
    private(set) var loadError: String?

    init(repository: WorkoutRepository, autoLoad: Bool = true) {
        self.repository = repository
        if autoLoad { reload() }
    }

    func reload() {
        do {
            workouts = try repository.all()
            loadError = nil
        } catch {
            workouts = []
            loadError = error.localizedDescription
        }
    }

    func save(_ workout: Workout) throws {
        try repository.save(workout)
        reload()
    }

    func delete(_ workout: Workout) throws {
        try repository.delete(id: workout.id)
        reload()
    }

    /// Writes each sample workout only if the library is currently empty.
    func seedIfEmpty(with samples: [Workout]) {
        guard workouts.isEmpty else { return }
        for sample in samples {
            try? repository.save(sample)
        }
        reload()
    }
}
