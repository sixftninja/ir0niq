import SwiftUI

struct TemplateEditorView: View {
    var existingTemplate: TemplateDTO? = nil

    @Environment(TemplateViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedExercises: [ExerciseEditorRow] = []
    @State private var showExercisePicker = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Push Day", text: $name)
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
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
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
                    selectedExercises.append(ExerciseEditorRow(exercise: exercise))
                    showExercisePicker = false
                }
            }
            
        }
        .onAppear(perform: populateFromExisting)
    }

    @ViewBuilder
    private func exerciseEditorRow(_ row: Binding<ExerciseEditorRow>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.wrappedValue.exercise.name)
                    .font(.body).bold()
                    .foregroundStyle(.white)
                Spacer()
                Stepper("", value: row.sets, in: 1...20)
                    .labelsHidden()
                Text("\(row.wrappedValue.sets) sets")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 48)
            }
            HStack(spacing: 16) {
                labeledField("Reps", value: row.reps)
                labeledField("Weight (kg)", value: row.weight)
                labeledField("Rest (s)", value: row.restSeconds)
            }
        }
        .padding(.vertical, 4)
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
                .frame(width: 60)
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
                sets: ex.sets.count,
                reps: ex.sets.first?.targetReps,
                weight: ex.sets.first?.targetWeight.map { Int($0) },
                restSeconds: ex.sets.first?.restDuration.map { Int($0) }
            )
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        Task {
            let exerciseInputs = selectedExercises.map { row -> CreateTemplateExerciseInput in
                let sets = (0..<row.sets).map { _ in
                    CreateTemplateSetInput(
                        targetReps: row.reps,
                        targetWeight: row.weight.map { Double($0) },
                        restDuration: row.restSeconds.map { Double($0) }
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

// MARK: - Editor row model

struct ExerciseEditorRow: Identifiable {
    let id = UUID()
    var exercise: ExerciseDTO
    var sets: Int = 3
    var reps: Int? = 8
    var weight: Int? = nil
    var restSeconds: Int? = 90
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
