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

    private var displayTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (existingTemplate == nil ? "New Template" : "Edit Template") : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Push Day", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("template_name_field")
                }
                .listRowBackground(Color(white: 0.1))

                Section("Exercises") {
                    ForEach($selectedExercises) { $row in
                        exerciseEditorRow($row)
                    }
                    .onMove { vm.moveExercise(&selectedExercises, from: $0, to: $1) }
                    .onDelete { selectedExercises.remove(atOffsets: $0) }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.forgeOrange)
                    }
                    .accessibilityIdentifier("add_exercise_button")
                }
                .listRowBackground(Color(white: 0.1))
            }
            .scrollContentBackground(.hidden)
            .background(Color.forgeDark)
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .accessibilityIdentifier("save_template_button")
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    let newRow = ExerciseEditorRow(exercise: exercise)
                    selectedExercises.append(newRow)
                    expandedExerciseId = newRow.id
                    showExercisePicker = false
                }
            }
        }
        .onAppear(perform: populateFromExisting)
    }

    @ViewBuilder
    private func exerciseEditorRow(_ row: Binding<ExerciseEditorRow>) -> some View {
        let isExpanded = expandedExerciseId == row.wrappedValue.id
        VStack(alignment: .leading, spacing: 0) {
            // Header row — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedExerciseId = isExpanded ? nil : row.wrappedValue.id
                }
            } label: {
                HStack {
                    Text(row.wrappedValue.exercise.name)
                        .font(.body).bold()
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(row.wrappedValue.setRows.count) sets")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
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
                ForEach(row.wrappedValue.setRows.indices, id: \.self) { i in
                    setRow(index: i, row: row)
                }

                Button {
                    row.wrappedValue.setRows.append(SetEditorRow())
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.forgeOrange)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func setRow(index: Int, row: Binding<ExerciseEditorRow>) -> some View {
        HStack(spacing: 12) {
            Text("Set \(index + 1)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 36, alignment: .leading)
            labeledField("Reps", value: row.setRows[index].reps)
            labeledField("kg", value: row.setRows[index].weight)
            labeledField("Rest (s)", value: row.setRows[index].restSeconds)
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func labeledField(_ label: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            TextField("—", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 56)
                .padding(6)
                .background(Color(white: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        reps: s.targetReps,
                        weight: s.targetWeight.map { Int($0) },
                        restSeconds: s.restDuration.map { Int($0) }
                    )
                }
            )
        }
        expandedExerciseId = selectedExercises.first?.id
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        Task {
            let exerciseInputs = selectedExercises.map { row -> CreateTemplateExerciseInput in
                let sets = row.setRows.map { s in
                    CreateTemplateSetInput(
                        targetReps: s.reps,
                        targetWeight: s.weight.map { Double($0) },
                        restDuration: s.restSeconds.map { Double($0) }
                    )
                }
                return CreateTemplateExerciseInput(
                    exerciseId: row.exercise.id,
                    equipmentTypeOverride: nil,
                    sets: sets
                )
            }
            _ = try? await vm.createTemplate(name: trimmed, exercises: exerciseInputs)
            dismiss()
        }
    }
}

// MARK: - Editor row models

struct SetEditorRow: Identifiable {
    let id = UUID()
    var reps: Int? = 10
    var weight: Int? = nil
    var restSeconds: Int? = 30
}

struct ExerciseEditorRow: Identifiable {
    let id = UUID()
    var exercise: ExerciseDTO
    var setRows: [SetEditorRow] = [SetEditorRow(), SetEditorRow(), SetEditorRow()]
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
