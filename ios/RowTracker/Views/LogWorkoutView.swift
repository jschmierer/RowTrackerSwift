import SwiftUI

struct LogWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var form = WorkoutForm()
    @State private var saveError: String?
    @State private var justSaved: Workout?
    @FocusState private var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case sharedPrimary
        case primary(Int)
        case secondary(Int)
        case strokeRate(Int)
        case notes
    }

    private var kind: WorkoutKind { form.kind }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Workout date",
                               selection: $form.date,
                               in: ...Date(),
                               displayedComponents: .date)
                }

                Section("Workout type") {
                    Picker("Type", selection: $form.kind) {
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

                Section {
                    Toggle("Intervals", isOn: Binding(
                        get: { form.intervalsOn },
                        set: { form.setIntervalsOn($0) }
                    ))
                    if form.intervalsOn {
                        Toggle("Variable", isOn: Binding(
                            get: { form.variable },
                            set: { form.setVariable($0) }
                        ))
                        Stepper(value: Binding(
                            get: { form.rows.count },
                            set: { form.setIntervalCount($0) }
                        ), in: 2...WorkoutForm.maxIntervals) {
                            Text("\(form.rows.count) intervals")
                        }
                    }
                }

                Section {
                    Picker("Also enter", selection: Binding(
                        get: { form.secondary },
                        set: { form.setSecondary($0) }
                    )) {
                        ForEach(SecondaryField.allCases, id: \.self) { opt in
                            Text(opt.label(for: kind)).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Also enter")
                } footer: {
                    Text(kind == .timed
                         ? "Time plus one of these; the rest is worked out."
                         : "Distance plus one of these; the rest is worked out.")
                }

                if form.layout == .uniform {
                    Section {
                        TextField(kind.sharedPrimaryLabel, text: $form.sharedPrimaryStr)
                            .keyboardType(kind.primaryKeyboard)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .sharedPrimary)
                        if let err = form.sharedPrimaryError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text(kind.sharedPrimaryTitle)
                    } footer: {
                        Text("The same for every interval. Turn on Variable to set each one.")
                    }
                }

                ForEach(form.activeRowIndices, id: \.self) { idx in
                    intervalSection(index: idx)
                }

                Section("Notes (optional)") {
                    TextField("How did it feel? Rate, rig, drag...",
                              text: $form.notes, axis: .vertical)
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
        form = WorkoutForm()
        router.selectedTab = .dashboard
    }

    @ViewBuilder
    private func intervalSection(index: Int) -> some View {
        Section(form.intervalsOn ? "Interval \(index + 1)" : "Workout") {
            // Primary field — depends on workout type. In the shared
            // layout it lives once above the list instead.
            if form.layout != .uniform {
                TextField(kind.primaryFieldLabel, text: $form.rows[index].primaryStr)
                    .keyboardType(kind.primaryKeyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .primary(index))
            }

            TextField(form.secondary.fieldLabel(for: kind),
                      text: $form.rows[index].secondaryStr)
                .keyboardType(form.secondary.keyboard(for: kind))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .secondary(index))

            TextField("Stroke rate (optional, 10–60 spm)",
                      text: $form.rows[index].strokeRateStr)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .strokeRate(index))

            if let err = form.rows[index].error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func save() {
        saveError = nil
        guard let workout = form.makeWorkout() else {
            saveError = "Fix the highlighted fields and try again."
            return
        }
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
}

// MARK: - WorkoutKind UI helpers

private extension WorkoutKind {
    var primaryFieldLabel: String {
        switch self {
        case .timed: return "Time (M:SS or H:MM:SS)"
        case .distance: return "Distance (meters)"
        }
    }

    /// Section title for the shared field ("Time per interval").
    var sharedPrimaryTitle: String {
        switch self {
        case .timed: return "Time per interval"
        case .distance: return "Distance per interval"
        }
    }

    var sharedPrimaryLabel: String {
        switch self {
        case .timed: return "Time per interval (M:SS)"
        case .distance: return "Distance per interval (meters)"
        }
    }

    var primaryKeyboard: UIKeyboardType {
        switch self {
        case .timed: return .numbersAndPunctuation
        case .distance: return .decimalPad
        }
    }

}

private extension SecondaryField {
    /// Short label for the segmented control.
    func label(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "Split"
        case (.otherQuantity, .timed): return "Distance"
        case (.otherQuantity, .distance): return "Time"
        case (.watts, _): return "Watts"
        }
    }

    /// Full placeholder text for the text field.
    func fieldLabel(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "Split per 500 m (M:SS)"
        case (.otherQuantity, .timed): return "Distance (meters)"
        case (.otherQuantity, .distance): return "Time (M:SS or H:MM:SS)"
        case (.watts, _): return "Average watts"
        }
    }

    func keyboard(for kind: WorkoutKind) -> UIKeyboardType {
        switch (self, kind) {
        case (.split, _): return .numbersAndPunctuation
        case (.otherQuantity, .timed): return .decimalPad
        case (.otherQuantity, .distance): return .numbersAndPunctuation
        case (.watts, _): return .decimalPad
        }
    }
}
