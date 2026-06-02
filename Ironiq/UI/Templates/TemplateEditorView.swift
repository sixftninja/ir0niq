import SwiftUI

struct TemplateEditorView: View {
    var existingTemplate: TemplateDTO? = nil

    @Environment(TemplateViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedExercises: [ExerciseEditorRow] = []
    @State private var expandedExerciseId: UUID? = nil
    @State private var showExercisePicker = false
    @State private var isSaving = false
    @State private var step: EditorStep = .name

    private var displayTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (existingTemplate == nil ? "New Template" : "Edit Template") : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if step == .name {
                            nameStep
                        } else {
                            exerciseStep
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(excludedExerciseIds: Set(selectedExercises.map(\.exercise.id))) { exercise in
                    guard selectedExercises.contains(where: { $0.exercise.id == exercise.id }) == false else {
                        showExercisePicker = false
                        if let existing = selectedExercises.first(where: { $0.exercise.id == exercise.id }) {
                            expandedExerciseId = existing.id
                        }
                        return
                    }
                    var newRow = ExerciseEditorRow(exercise: exercise)
                    newRow.isBeingEdited = true
                    selectedExercises.append(newRow)
                    expandedExerciseId = newRow.id
                    showExercisePicker = false
                }
            }
        }
        .onAppear(perform: populateFromExisting)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Name Workout")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)
            TextField("Upper Body", text: $name)
                .textInputAutocapitalization(.words)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(name.isEmpty ? Color.white.opacity(0.08) : Color.ironiqOrange.opacity(0.55), lineWidth: 1)
                )
                .accessibilityIdentifier("template_name_field")
            IroniqButton("Next") {
                withAnimation(.easeInOut(duration: 0.2)) { step = .exercises }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
        }
    }
    private var exerciseStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Exercises")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)

            ForEach(selectedExercises) { row in
                exerciseEditorRow(row)
            }

            Button {
                handleExercisePrimaryAction()
            } label: {
                Label(exercisePrimaryTitle, systemImage: exercisePrimaryTitle == "Done" ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(exercisePrimaryTitle == "Done" ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(exercisePrimaryTitle == "Done" ? Color.ironiqGreen : Color.ironiqOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(exercisePrimaryTitle == "Done" ? Color.white.opacity(0.18) : .clear, lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("add_exercise_button")

            IroniqButton(existingTemplate == nil ? "Create" : "Save") { save() }
                .disabled(selectedExercises.isEmpty || isSaving)
                .opacity(selectedExercises.isEmpty || isSaving ? 0.45 : 1)
                .accessibilityIdentifier("save_template_button")
        }
    }

    @ViewBuilder
    private func exerciseEditorRow(_ row: ExerciseEditorRow) -> some View {
        let isExpanded = expandedExerciseId == row.id
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedExerciseId = isExpanded ? nil : row.id
                }
            } label: {
                HStack {
                    Text(row.exercise.name)
                        .font(.body).bold()
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(row.setRows.count) sets")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityIdentifier("template_exercise_set_count")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 4)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                exerciseRestPicker(row)

                ForEach(setEntries(for: row)) { entry in
                    setRow(exerciseId: row.id, setId: entry.id)
                }

                VStack(spacing: 10) {
                    Button {
                        addSet(to: row.id)
                    } label: {
                        Label("Set", systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.ironiqOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.ironiqOrange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add set")
                    .accessibilityIdentifier("template_add_set_button")

                    Button(role: .destructive) {
                        selectedExercises.removeAll { $0.id == row.id }
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.ironiqRed.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.ironiqRed.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove exercise")
                    .accessibilityIdentifier("template_remove_exercise_button")
                }
                .padding(.top, 10)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("selected_exercise_\(row.exercise.name.replacingOccurrences(of: " ", with: "_"))")
    }

    private func setEntries(for row: ExerciseEditorRow) -> [SetRowEntry] {
        row.setRows.enumerated().map { offset, setRow in
            SetRowEntry(id: setRow.id, index: offset)
        }
    }

    @ViewBuilder
    private func setRow(exerciseId: UUID, setId: UUID) -> some View {
        if let row = exerciseRow(id: exerciseId), let index = setIndex(id: setId, in: row) {
            VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Set \(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 44, alignment: .leading)

                targetTypeSwitch(exerciseId: exerciseId, setId: setId)

                Spacer(minLength: 8)

                if row.setRows.count > 1 {
                    Button {
                        removeSet(exerciseId: exerciseId, setId: setId)
                    } label: {
                        Label("Remove set", systemImage: "minus.circle")
                            .labelStyle(.iconOnly)
                            .font(.body)
                            .foregroundStyle(Color.ironiqRed.opacity(0.82))
                            .frame(width: 44, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove set")
                    .accessibilityIdentifier("template_remove_set_button")
                }
            }

            if setTargetType(exerciseId: exerciseId, setId: setId) == .duration {
                targetNumberField(label: "Target duration", value: dirtyIntBinding(exerciseId: exerciseId, setId: setId, keyPath: \.targetDurationSeconds), placeholder: "30")
                    .accessibilityIdentifier("target_duration_field")
            } else {
                targetNumberField(label: "Target reps", value: dirtyIntBinding(exerciseId: exerciseId, setId: setId, keyPath: \.targetReps), placeholder: "10")
                    .accessibilityIdentifier("target_reps_field")
            }
        }
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 6)
        }
    }

    private func exerciseIndex(id: UUID) -> Int? {
        selectedExercises.firstIndex { $0.id == id }
    }

    private func exerciseRow(id: UUID) -> ExerciseEditorRow? {
        selectedExercises.first { $0.id == id }
    }

    private func setIndex(id: UUID, in row: ExerciseEditorRow) -> Int? {
        row.setRows.firstIndex { $0.id == id }
    }

    private func setTargetType(exerciseId: UUID, setId: UUID) -> SetLoggingType? {
        exerciseRow(id: exerciseId)?.setRows.first { $0.id == setId }?.targetType
    }

    private func addSet(to exerciseId: UUID) {
        guard let exerciseIndex = exerciseIndex(id: exerciseId) else { return }
        let previousSet = selectedExercises[exerciseIndex].setRows.last ?? SetEditorRow()
        selectedExercises[exerciseIndex].isBeingEdited = true
        selectedExercises[exerciseIndex].setRows.append(previousSet.duplicated())
    }

    private func removeSet(exerciseId: UUID, setId: UUID) {
        guard let exerciseIndex = exerciseIndex(id: exerciseId) else { return }
        guard selectedExercises[exerciseIndex].setRows.count > 1 else { return }
        selectedExercises[exerciseIndex].isBeingEdited = true
        selectedExercises[exerciseIndex].setRows.removeAll { $0.id == setId }
    }

    private func targetTypeSwitch(exerciseId: UUID, setId: UUID) -> some View {
        let isDuration = Binding<Bool>(
            get: {
                setTargetType(exerciseId: exerciseId, setId: setId) == .duration
            },
            set: { newValue in
                guard let exerciseIndex = exerciseIndex(id: exerciseId) else { return }
                guard let setIndex = setIndex(id: setId, in: selectedExercises[exerciseIndex]) else { return }
                selectedExercises[exerciseIndex].isBeingEdited = true
                selectedExercises[exerciseIndex].setRows[setIndex].targetType = newValue ? .duration : .reps
            }
        )
        return HStack(spacing: 6) {
            Text("Reps")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isDuration.wrappedValue ? .white.opacity(0.38) : Color.ironiqOrange)
            Toggle("", isOn: isDuration)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.72)
                .tint(Color.ironiqOrange)
                .frame(width: 44)
            Text("Time")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isDuration.wrappedValue ? Color.ironiqOrange : .white.opacity(0.38))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.055))
        .clipShape(Capsule())
    }

    private func dirtyIntBinding(exerciseId: UUID, setId: UUID, keyPath: WritableKeyPath<SetEditorRow, Int>) -> Binding<Int> {
        Binding<Int>(
            get: {
                exerciseRow(id: exerciseId)?.setRows.first { $0.id == setId }?[keyPath: keyPath] ?? 0
            },
            set: { newValue in
                guard let exerciseIndex = exerciseIndex(id: exerciseId) else { return }
                guard let setIndex = setIndex(id: setId, in: selectedExercises[exerciseIndex]) else { return }
                selectedExercises[exerciseIndex].isBeingEdited = true
                selectedExercises[exerciseIndex].setRows[setIndex][keyPath: keyPath] = newValue
            }
        )
    }

    @ViewBuilder
    private func exerciseRestPicker(_ row: ExerciseEditorRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rest target for \(row.exercise.name)", systemImage: "timer")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
            Stepper("\(row.restSeconds)s between sets", value: dirtyRestBinding(exerciseId: row.id), in: 0...600, step: 5)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .tint(Color.ironiqOrange)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 12)
    }

    private func dirtyRestBinding(exerciseId: UUID) -> Binding<Int> {
        Binding<Int>(
            get: { exerciseRow(id: exerciseId)?.restSeconds ?? 30 },
            set: { newValue in
                guard let exerciseIndex = exerciseIndex(id: exerciseId) else { return }
                selectedExercises[exerciseIndex].isBeingEdited = true
                selectedExercises[exerciseIndex].restSeconds = newValue
            }
        )
    }

    private func targetNumberField(label: String, value: Binding<Int>, placeholder: String) -> some View {
        let defaultValue = Int(placeholder) ?? 0
        return HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            DefaultPlaceholderIntField(value: value, defaultValue: defaultValue, width: 82)
                .font(.headline.monospacedDigit().weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func populateFromExisting() {
        guard let t = existingTemplate else { return }
        name = t.name
        selectedExercises = t.exercises.sorted { $0.order < $1.order }.map { ex in
            ExerciseEditorRow(
                exercise: ExerciseDTO(
                    id: ex.exerciseId, name: ex.exerciseName,
                    exerciseDescription: "", equipmentType: ex.equipmentTypeOverride ?? .barbell,
                    isSingleHand: false, muscleGroups: [], iconName: "", isCustom: false, isSeeded: false
                ),
                setRows: ex.sets.sorted { $0.order < $1.order }.map { s in
                    SetEditorRow(
                        targetType: s.targetDuration == nil ? .reps : .duration,
                        targetReps: s.targetReps ?? 10,
                        targetDurationSeconds: Int(s.targetDuration ?? 30)
                    )
                },
                restSeconds: Int(ex.sets.first?.restDuration ?? 30)
            )
        }
        expandedExerciseId = nil
        step = .exercises
    }


    private var activeEditingExerciseIndex: Int? {
        guard let expandedExerciseId else { return nil }
        return selectedExercises.firstIndex { $0.id == expandedExerciseId && $0.isBeingEdited }
    }

    private var exercisePrimaryTitle: String {
        activeEditingExerciseIndex == nil ? "Add Exercise" : "Done"
    }

    private func handleExercisePrimaryAction() {
        if let index = activeEditingExerciseIndex {
            selectedExercises[index].isBeingEdited = false
            withAnimation(.easeInOut(duration: 0.2)) { expandedExerciseId = nil }
        } else {
            showExercisePicker = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        Task {
            let exerciseInputs = selectedExercises.map { row -> CreateTemplateExerciseInput in
                let sets = row.setRows.map { s in
                    CreateTemplateSetInput(
                        targetReps: s.targetType == .reps ? s.targetReps : nil,
                        targetDuration: s.targetType == .duration ? Double(s.targetDurationSeconds) : nil,
                        restDuration: Double(row.restSeconds)
                    )
                }
                return CreateTemplateExerciseInput(
                    exerciseId: row.exercise.id,
                    equipmentTypeOverride: nil,
                    sets: sets
                )
            }
            do {
                if let existingTemplate {
                    try await vm.updateTemplate(id: existingTemplate.id, name: trimmed, exercises: exerciseInputs)
                } else {
                    _ = try await vm.createTemplate(name: trimmed, exercises: exerciseInputs)
                }
                dismiss()
            } catch {
                vm.alertMessage = error.localizedDescription
                vm.showAlert = true
            }
        }
    }
}

private struct SetRowEntry: Identifiable {
    let id: UUID
    let index: Int
}

// MARK: - Editor row models

struct SetEditorRow: Identifiable {
    let id: UUID
    var targetType: SetLoggingType
    var targetReps: Int
    var targetDurationSeconds: Int

    init(id: UUID = UUID(), targetType: SetLoggingType = .reps, targetReps: Int = 10, targetDurationSeconds: Int = 30) {
        self.id = id
        self.targetType = targetType
        self.targetReps = targetReps
        self.targetDurationSeconds = targetDurationSeconds
    }

    func duplicated() -> SetEditorRow {
        SetEditorRow(targetType: targetType, targetReps: targetReps, targetDurationSeconds: targetDurationSeconds)
    }
}

struct ExerciseEditorRow: Identifiable {
    let id = UUID()
    var exercise: ExerciseDTO
    var setRows: [SetEditorRow] = [SetEditorRow()]
    var restSeconds: Int = 30
    var isBeingEdited = false
}

private enum EditorStep {
    case name
    case exercises
}

extension TemplateViewModel {
    func moveExercise(_ rows: inout [ExerciseEditorRow], from: IndexSet, to: Int) {
        rows.move(fromOffsets: from, toOffset: to)
    }
}

#Preview {
    TemplateEditorView()
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
}
