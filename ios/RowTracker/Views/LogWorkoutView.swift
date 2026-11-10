import SwiftUI

struct LogWorkoutView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var form = WorkoutForm()
    @State private var saveError: String?
    @State private var justSaved: Workout?
    /// Set by "Share workout": the share sheet opens first, and the saved
    /// workout's detail sheet follows when it closes.
    @State private var sharing: ShareText?
    @State private var savedWhileSharing: Workout?
    @FocusState private var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case sharedPrimary
        case primary(UUID)
        case secondary(UUID)
        case strokeRate(UUID)
        case avgHR
        case maxHR
        case notes
        case customTitle
        case customDetails
        case sharedRest
        case rest(UUID)
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
                        ForEach(WorkoutKind.allCases, id: \.self) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("workoutTypePicker")
                    Text(kind.typeCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if kind == .custom {
                    customSections
                } else {
                    intervalSections
                }

                Section {
                    Toggle("Record heart rate", isOn: $form.recordHeartRate)
                    if form.recordHeartRate {
                        TextField("Average HR (bpm)", text: $form.avgHRStr)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .avgHR)
                        TextField("Max HR (bpm)", text: $form.maxHRStr)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .maxHR)
                        if let err = form.heartRateError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    if form.recordHeartRate {
                        Text("For the whole workout, not each interval.")
                    }
                }

                Section("Effort") {
                    HStack {
                        Text("Effort level")
                        Spacer()
                        Text("\(form.effort) / 10")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(form.effort) },
                            set: { form.effort = Int($0.rounded()) }
                        ),
                        in: 0...10,
                        step: 1
                    ) {
                        Text("Effort level")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("10")
                    }
                    .accessibilityValue("\(form.effort) out of 10")
                }

                Section("Notes") {
                    // Starts three lines tall so it reads as a multi-line
                    // box, grows to eight, then scrolls.
                    TextField("How did it feel? Rig, drag, anything else (optional)",
                              text: $form.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .notes)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: saveAndShare) {
                        Label("Share workout", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("shareWorkoutButton")
                } footer: {
                    Text("Saves the workout, then opens the share sheet.")
                }
            }
            .navigationTitle("Log Workout")
            // Keyboard dismissal: swipe the form down, or the Done button
            // above the keyboard. Don't add .onTapGesture to the Form for
            // this: it takes taps away from Form-row buttons, which is
            // what broke "+ Add interval" in build 4.
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(item: $sharing, onDismiss: {
                justSaved = savedWhileSharing
                savedWhileSharing = nil
            }) { item in
                ActivityView(text: item.text) { sharing = nil }
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
            .sheet(item: $justSaved) { saved in
                NavigationStack {
                    WorkoutDetailView(workout: saved, navigationTitle: "Saved")
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

    /// Time and Distance: the interval toggles, the "also enter" metric,
    /// and the interval rows.
    @ViewBuilder
    private var intervalSections: some View {
        Section {
            Toggle("Intervals", isOn: Binding(
                get: { form.intervalsOn },
                set: { form.setIntervalsOn($0) }
            ))
            .accessibilityIdentifier("intervalsToggle")
            if form.intervalsOn {
                Toggle("Variable", isOn: Binding(
                    get: { form.variable },
                    set: { form.setVariable($0) }
                ))
                .accessibilityIdentifier("variableToggle")
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
            // "the others", not "the rest": rest means time off here.
            Text(kind == .timed
                 ? "Time plus one of these; the others are worked out."
                 : "Distance plus one of these; the others are worked out.")
        }

        if form.intervalsOn {
            // Mockup order: Variable rest, the shared time/distance (shared
            // intervals only), then the shared rest (Variable rest off).
            Section {
                Toggle("Variable rest", isOn: Binding(
                    get: { form.variableRest },
                    set: { form.setVariableRest($0) }
                ))
                .accessibilityIdentifier("variableRestToggle")

                if form.layout == .uniform {
                    TextField(kind.sharedPrimaryLabel, text: $form.sharedPrimaryStr)
                        .keyboardType(kind.primaryKeyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .sharedPrimary)
                        .accessibilityIdentifier("sharedPrimaryField")
                    if let err = form.sharedPrimaryError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if form.showsSharedRest {
                    TextField("Rest per interval (M:SS, optional)", text: $form.sharedRestStr)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .sharedRest)
                        .accessibilityIdentifier("sharedRestField")
                    if let err = form.sharedRestError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text(form.layout == .uniform ? kind.sharedPrimaryTitle : "Rest")
            } footer: {
                Text(perIntervalFooter)
            }
        }

        ForEach(form.activeRowIndices.map { form.rows[$0].id }, id: \.self) { id in
            intervalSection(id: id)
            if let index = form.rows.firstIndex(where: { $0.id == id }),
               form.restRowIndices.contains(index) {
                restSection(id: id, index: index)
            }
        }

        if form.intervalsOn {
            Section {
                Button {
                    focusedField = nil
                    form.addInterval()
                } label: {
                    Label("Add interval", systemImage: "plus.circle.fill")
                }
                .disabled(!form.canAddInterval)
                .accessibilityIdentifier("addIntervalButton")
            }
        }
    }

    /// Custom: a required title and free-text details, nothing else.
    @ViewBuilder
    private var customSections: some View {
        Section {
            TextField("Workout title", text: $form.customTitle)
                .focused($focusedField, equals: .customTitle)
                .accessibilityIdentifier("customTitleField")
            if let err = form.customTitleError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("customTitleError")
            }
        } header: {
            Text("Workout title")
        }

        Section("Details") {
            TextField("What did you do? Sets, distance, pace (optional)",
                      text: $form.customDetails, axis: .vertical)
                .lineLimit(3...10)
                .focused($focusedField, equals: .customDetails)
                .accessibilityIdentifier("customDetailsField")
        }
    }

    private func finishSave() {
        justSaved = nil
        form = WorkoutForm()
        router.selectedTab = .dashboard
    }

    /// Binding to one row by id, so removing a row can't leave a field
    /// bound to a stale array index.
    private func row(_ id: UUID) -> Binding<IntervalFormRow> {
        Binding(
            get: { form.rows.first { $0.id == id } ?? IntervalFormRow() },
            set: { newValue in
                if let i = form.rows.firstIndex(where: { $0.id == id }) {
                    form.rows[i] = newValue
                }
            }
        )
    }

    private var perIntervalFooter: String {
        let rest = form.variableRest
            ? "Enter the rest after each interval."
            : "Rest is the same after every interval but the last."
        let shared = form.layout == .uniform
            ? "Time or distance is the same for every interval; turn on Variable to set each one. "
            : ""
        return shared + rest + " Rest isn't counted in time, distance, or splits."
    }

    /// The optional rest between interval `index` and the next one.
    @ViewBuilder
    private func restSection(id: UUID, index: Int) -> some View {
        let row = row(id)
        Section {
            TextField("Rest (M:SS, optional)", text: row.restStr)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .rest(id))
                .accessibilityIdentifier("restField.\(index + 1)")
            if let err = row.wrappedValue.restError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Rest after interval \(index + 1)")
        }
    }

    @ViewBuilder
    private func intervalSection(id: UUID) -> some View {
        let index = form.rows.firstIndex { $0.id == id } ?? 0
        let row = row(id)
        Section {
            // Primary field — depends on workout type. In the shared
            // layout it lives once above the list instead.
            if form.layout != .uniform {
                TextField(kind.primaryFieldLabel, text: row.primaryStr)
                    .keyboardType(kind.primaryKeyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .primary(id))
                    .accessibilityIdentifier("primaryField.\(index + 1)")
            }

            TextField(form.secondary.fieldLabel(for: kind), text: row.secondaryStr)
                .keyboardType(form.secondary.keyboard(for: kind))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .secondary(id))
                .accessibilityIdentifier("secondaryField.\(index + 1)")

            TextField("Stroke rate (optional, 10–60 spm)", text: row.strokeRateStr)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .strokeRate(id))

            if let err = row.wrappedValue.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            if form.intervalsOn {
                HStack {
                    Text("Interval \(index + 1)")
                        .accessibilityIdentifier("intervalTitle.\(index + 1)")
                    Spacer()
                    if index > 0 {
                        Button(role: .destructive) {
                            focusedField = nil
                            form.removeInterval(id: id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("Remove interval \(index + 1)")
                        .accessibilityIdentifier("removeIntervalButton.\(index + 1)")
                    }
                }
            } else {
                Text("Workout")
            }
        }
    }

    private func save() {
        guard let workout = validateAndStore() else { return }
        // Show the fresh workout so the rower can confirm it was recorded
        // correctly. The form is cleared by `finishSave()` when they tap
        // Done, which also switches to the Dashboard tab.
        justSaved = workout
    }

    /// "Share workout": save exactly like Save, open the share sheet with
    /// the summary, then show the saved workout when the sheet closes.
    private func saveAndShare() {
        guard let workout = validateAndStore() else { return }
        savedWhileSharing = workout
        sharing = ShareText(text: WorkoutShareText.make(for: workout))
    }

    private func validateAndStore() -> Workout? {
        focusedField = nil
        saveError = nil
        guard let workout = form.makeWorkout() else {
            saveError = "Fix the highlighted fields and try again."
            return nil
        }
        do {
            try store.save(workout)
            return workout
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - WorkoutKind UI helpers

private extension WorkoutKind {
    var typeCaption: String {
        switch self {
        case .timed: return "Row for a given time (e.g. 20 minutes), log how far you went."
        case .distance: return "Row for a given distance (e.g. 2000 m), log how long it took."
        case .custom: return "Anything else: a bike, a run, weights. Give it a title and describe it."
        }
    }

    var primaryFieldLabel: String {
        switch self {
        case .timed, .custom: return "Time (M:SS or H:MM:SS)"
        case .distance: return "Distance (meters)"
        }
    }

    /// Section title for the shared field ("Time per interval").
    var sharedPrimaryTitle: String {
        switch self {
        case .timed, .custom: return "Time per interval"
        case .distance: return "Distance per interval"
        }
    }

    var sharedPrimaryLabel: String {
        switch self {
        case .timed, .custom: return "Time per interval (M:SS)"
        case .distance: return "Distance per interval (meters)"
        }
    }

    var primaryKeyboard: UIKeyboardType {
        switch self {
        case .timed, .custom: return .numbersAndPunctuation
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
        case (.otherQuantity, .distance), (.otherQuantity, .custom): return "Time"
        case (.watts, _): return "Watts"
        }
    }

    /// Full placeholder text for the text field.
    func fieldLabel(for kind: WorkoutKind) -> String {
        switch (self, kind) {
        case (.split, _): return "Split per 500 m (M:SS)"
        case (.otherQuantity, .timed): return "Distance (meters)"
        case (.otherQuantity, .distance), (.otherQuantity, .custom): return "Time (M:SS or H:MM:SS)"
        case (.watts, _): return "Average watts"
        }
    }

    func keyboard(for kind: WorkoutKind) -> UIKeyboardType {
        switch (self, kind) {
        case (.split, _): return .numbersAndPunctuation
        case (.otherQuantity, .timed): return .decimalPad
        case (.otherQuantity, .distance), (.otherQuantity, .custom): return .numbersAndPunctuation
        case (.watts, _): return .decimalPad
        }
    }
}
