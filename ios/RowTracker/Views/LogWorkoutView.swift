import SwiftUI

struct LogWorkoutView: View {
    @Environment(WorkoutStore.self) private var store

    @State private var kind: WorkoutKind = .timed
    @State private var intervalCount: Int = 1
    @State private var rows: [IntervalFormRow] = [IntervalFormRow()]
    @State private var notes: String = ""
    @State private var saveError: String?
    @State private var showSavedBanner: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout type") {
                    Picker("Type", selection: $kind) {
                        Text("Timed").tag(WorkoutKind.timed)
                        Text("Distance").tag(WorkoutKind.distance)
                    }
                    .pickerStyle(.segmented)
                    Text(kind == .timed
                         ? "Row for a given time (e.g. 20 minutes), log how far you went."
                         : "Row for a given distance (e.g. 2000 m), log how long it took.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Intervals") {
                    Stepper(value: $intervalCount, in: 1...20) {
                        Text("\(intervalCount) interval\(intervalCount == 1 ? "" : "s")")
                    }
                    .onChange(of: intervalCount) { _, newCount in
                        syncRowCount(to: newCount)
                    }
                    Text("Enter any two of time, distance, split. The third will be computed for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(rows.indices, id: \.self) { idx in
                    Section("Interval \(idx + 1)") {
                        TextField("Time (M:SS or H:MM:SS)", text: $rows[idx].timeStr)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Distance (meters)", text: $rows[idx].distanceStr)
                            .keyboardType(.decimalPad)
                        TextField("Split per 500 m (M:SS)", text: $rows[idx].splitStr)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let err = rows[idx].error {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("How did it feel? Rate, rig, drag...", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }

                if showSavedBanner {
                    Section {
                        Label("Workout saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Log Workout")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
        }
    }

    private func syncRowCount(to n: Int) {
        if n > rows.count {
            rows.append(contentsOf: (0..<(n - rows.count)).map { _ in IntervalFormRow() })
        } else if n < rows.count {
            rows = Array(rows.prefix(n))
        }
    }

    private func save() {
        showSavedBanner = false
        saveError = nil

        var updated = rows
        var intervals: [Interval] = []
        var hadError = false

        for i in updated.indices {
            do {
                intervals.append(try updated[i].derive())
                updated[i].error = nil
            } catch {
                updated[i].error = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                hadError = true
            }
        }
        rows = updated

        guard !hadError else {
            saveError = "Fix the highlighted intervals and try again."
            return
        }

        let workout = Workout(kind: kind,
                              date: Date(),
                              notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                              intervals: intervals)
        do {
            try store.save(workout)
            resetForm()
            showSavedBanner = true
            // Hide the banner after a short delay.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                showSavedBanner = false
            }
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func resetForm() {
        intervalCount = 1
        rows = [IntervalFormRow()]
        notes = ""
    }
}

struct IntervalFormRow: Identifiable {
    let id = UUID()
    var timeStr: String = ""
    var distanceStr: String = ""
    var splitStr: String = ""
    var error: String?

    enum DeriveError: LocalizedError {
        case tooFew
        case message(String)

        var errorDescription: String? {
            switch self {
            case .tooFew:
                return "Fill in any two of time, distance, and split."
            case .message(let m):
                return m
            }
        }
    }

    func derive() throws -> Interval {
        let hasTime = !timeStr.trimmingCharacters(in: .whitespaces).isEmpty
        let hasDist = !distanceStr.trimmingCharacters(in: .whitespaces).isEmpty
        let hasSplit = !splitStr.trimmingCharacters(in: .whitespaces).isEmpty

        guard [hasTime, hasDist, hasSplit].filter({ $0 }).count >= 2 else {
            throw DeriveError.tooFew
        }

        // Prefer the two most "primary" fields: time + distance wins.
        if hasTime && hasDist {
            let t = try RowingMath.parseTime(timeStr)
            guard let d = Double(distanceStr), d > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            guard t > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            return Interval(durationSec: t, distanceMeters: d)
        }
        if hasTime && hasSplit {
            let t = try RowingMath.parseTime(timeStr)
            let s = try RowingMath.parseTime(splitStr)
            guard t > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            guard s > 0 else { throw DeriveError.message("Split must be greater than zero.") }
            let d = RowingMath.distance(fromTime: t, split: s).rounded()
            return Interval(durationSec: t, distanceMeters: d)
        }
        // hasDist && hasSplit
        guard let d = Double(distanceStr), d > 0 else {
            throw DeriveError.message("Distance must be a positive number of meters.")
        }
        let s = try RowingMath.parseTime(splitStr)
        guard s > 0 else { throw DeriveError.message("Split must be greater than zero.") }
        let t = RowingMath.time(fromDistance: d, split: s)
        return Interval(durationSec: t, distanceMeters: d)
    }
}
