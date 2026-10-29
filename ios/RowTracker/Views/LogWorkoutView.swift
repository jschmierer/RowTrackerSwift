import SwiftUI

struct LogWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var kind: WorkoutKind = .timed
    @State private var date: Date = Date()
    @State private var intervalCount: Int = 1
    @State private var rows: [IntervalFormRow] = [IntervalFormRow()]
    @State private var notes: String = ""
    @State private var saveError: String?
    @State private var justSaved: Workout?
    @FocusState private var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case primary(Int)
        case secondary(Int)
        case strokeRate(Int)
        case notes
    }

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

                Section("Date") {
                    DatePicker("Workout date",
                               selection: $date,
                               in: ...Date(),
                               displayedComponents: .date)
                }

                Section("Intervals") {
                    Stepper(value: $intervalCount, in: 1...20) {
                        Text("\(intervalCount) interval\(intervalCount == 1 ? "" : "s")")
                    }
                    .onChange(of: intervalCount) { _, newCount in
                        syncRowCount(to: newCount)
                    }
                }

                ForEach(rows.indices, id: \.self) { idx in
                    intervalSection(index: idx)
                }

                Section("Notes (optional)") {
                    TextField("How did it feel? Rate, rig, drag...", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .notes)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log Workout")
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                // Taps on empty Form space don't normally end editing with a
                // number-pad focused; nudge first responder down to the window.
                focusedField = nil
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $justSaved) { saved in
                NavigationStack {
                    WorkoutDetailView(workout: saved)
                        .navigationTitle("Saved")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { finishSave() }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
    }

    private func finishSave() {
        justSaved = nil
        resetForm()
        router.selectedTab = .dashboard
    }

    @ViewBuilder
    private func intervalSection(index: Int) -> some View {
        Section("Interval \(index + 1)") {
            // Primary field — depends on workout type.
            TextField(kind.primaryFieldLabel, text: $rows[index].primaryStr)
                .keyboardType(kind.primaryKeyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .primary(index))

            // Secondary picker + value.
            Picker("Also enter", selection: $rows[index].secondary) {
                ForEach(kind.secondaryOptions, id: \.self) { opt in
                    Text(opt.label(for: kind)).tag(opt)
                }
            }
            .pickerStyle(.segmented)
            TextField(rows[index].secondary.fieldLabel(for: kind),
                      text: $rows[index].secondaryStr)
                .keyboardType(rows[index].secondary.keyboard(for: kind))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .secondary(index))

            TextField("Stroke rate (optional, 10–60 spm)",
                      text: $rows[index].strokeRateStr)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .strokeRate(index))

            if let err = rows[index].error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
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
        saveError = nil

        var updated = rows
        var intervals: [Interval] = []
        var hadError = false

        for i in updated.indices {
            do {
                intervals.append(try updated[i].derive(kind: kind))
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
                              date: RowingDate.startOfLocalDay(for: date),
                              notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                              intervals: intervals)
        do {
            try store.save(workout)
            // Show the fresh workout so the rower can confirm it was recorded
            // correctly. The form is cleared by `finishSave()` when they tap
            // Done, which also switches to the Dashboard tab.
            justSaved = workout
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func resetForm() {
        date = Date()
        intervalCount = 1
        rows = [IntervalFormRow()]
        notes = ""
    }
}

// MARK: - Form row

/// One interval's inputs: the primary value (time for a Timed workout,
/// distance for a Distance workout) plus one secondary (split or the other
/// quantity). The third value is derived in `derive(kind:)`.
struct IntervalFormRow: Identifiable {
    let id = UUID()
    var primaryStr: String = ""
    var secondary: SecondaryField = .split
    var secondaryStr: String = ""
    /// Stroke rate (spm). Optional on the form — blank saves as nil.
    var strokeRateStr: String = ""
    var error: String?

    /// Accepted stroke-rate range (strokes per minute).
    static let strokeRateRange = 10...60

    enum DeriveError: LocalizedError {
        case missing(String)
        case message(String)

        var errorDescription: String? {
            switch self {
            case .missing(let field): return "Enter a value for \(field)."
            case .message(let m): return m
            }
        }
    }

    func derive(kind: WorkoutKind) throws -> Interval {
        let primary = primaryStr.trimmingCharacters(in: .whitespaces)
        let secondaryText = secondaryStr.trimmingCharacters(in: .whitespaces)
        guard !primary.isEmpty else {
            throw DeriveError.missing(kind.primaryFieldName)
        }
        guard !secondaryText.isEmpty else {
            throw DeriveError.missing(secondary.fieldName)
        }

        let strokeRate = try parseStrokeRate()

        switch (kind, secondary) {
        case (.timed, .split):
            let time = try RowingMath.parseTime(primary)
            let split = try RowingMath.parseTime(secondaryText)
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            guard split > 0 else { throw DeriveError.message("Split must be greater than zero.") }
            let distance = RowingMath.distance(fromTime: time, split: split).rounded()
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.timed, .otherQuantity):
            // Timed + distance
            let time = try RowingMath.parseTime(primary)
            guard let distance = Double(secondaryText), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .split):
            guard let distance = Double(primary), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            let split = try RowingMath.parseTime(secondaryText)
            guard split > 0 else { throw DeriveError.message("Split must be greater than zero.") }
            let time = RowingMath.time(fromDistance: distance, split: split)
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)

        case (.distance, .otherQuantity):
            // Distance + time
            guard let distance = Double(primary), distance > 0 else {
                throw DeriveError.message("Distance must be a positive number of meters.")
            }
            let time = try RowingMath.parseTime(secondaryText)
            guard time > 0 else { throw DeriveError.message("Time must be greater than zero.") }
            return Interval(durationSec: time, distanceMeters: distance, strokeRate: strokeRate)
        }
    }

    /// Returns nil for a blank field (so the stored column stays NULL), the
    /// parsed value for an in-range integer, and throws a friendly message
    /// otherwise.
    func parseStrokeRate() throws -> Int? {
        let trimmed = strokeRateStr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), Self.strokeRateRange.contains(value) else {
            throw DeriveError.message("Stroke rate must be a whole number from 10 to 60.")
        }
        return value
    }
}

/// Which secondary value the rower is entering. The third value is computed
/// from the primary (set by the workout type) and this one.
enum SecondaryField: Hashable {
    case split
    case otherQuantity   // "distance" for a Timed workout, "time" for a Distance workout
}

// MARK: - WorkoutKind UI helpers

private extension WorkoutKind {
    var primaryFieldName: String {
        switch self {
        case .timed: return "time"
        case .distance: return "distance"
        }
    }

    var primaryFieldLabel: String {
        switch self {
        case .timed: return "Time (M:SS or H:MM:SS)"
        case .distance: return "Distance (meters)"
        }
    }

    var primaryKeyboard: UIKeyboardType {
        switch self {
        case .timed: return .numbersAndPunctuation
        case .distance: return .decimalPad
        }
    }

    var secondaryOptions: [SecondaryField] {
        [.split, .otherQuantity]
    }
}

private extension SecondaryField {
    /// Short label for the segmented control.
    func label(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "Split"
        case (.otherQuantity, .timed): return "Distance"
        case (.otherQuantity, .distance): return "Time"
        }
    }

    /// Prose label used in error messages ("Enter a value for <this>").
    var fieldName: String {
        switch self {
        case .split: return "split"
        case .otherQuantity: return "the other value"
        }
    }

    /// Full placeholder text for the text field.
    func fieldLabel(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "Split per 500 m (M:SS)"
        case (.otherQuantity, .timed): return "Distance (meters)"
        case (.otherQuantity, .distance): return "Time (M:SS or H:MM:SS)"
        }
    }

    func keyboard(for kind: WorkoutKind) -> UIKeyboardType {
        switch (self, kind) {
        case (.split, _): return .numbersAndPunctuation
        case (.otherQuantity, .timed): return .decimalPad
        case (.otherQuantity, .distance): return .numbersAndPunctuation
        }
    }
}
