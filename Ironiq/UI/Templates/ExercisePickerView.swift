import SwiftUI

struct ExercisePickerView: View {
    @Environment(TemplateViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    var excludedExerciseIds: Set<UUID> = []
    let onSelect: (ExerciseDTO) -> Void

    @State private var searchText = ""
    @State private var showCustomExercise = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.exercisesByMuscleGroup().filter { group in
                    searchText.isEmpty || group.exercises.contains {
                        $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                }, id: \.group) { item in
                    Section(item.group.displayName) {
                        ForEach(item.exercises.filter {
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                        }) { exercise in
                            let isExcluded = excludedExerciseIds.contains(exercise.id)
                            ExerciseRowView(exercise: exercise)
                                .opacity(isExcluded ? 0.38 : 1)
                                .overlay(alignment: .trailing) {
                                    if isExcluded {
                                        Text("Added")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.ironiqGreen)
                                    }
                                }
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onTapGesture {
                                    guard isExcluded == false else { return }
                                    onSelect(exercise)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("exercise_\(exercise.name.replacingOccurrences(of: " ", with: "_"))")
                        }
                    }
                    .listRowBackground(Color(white: 0.1))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.ironiqDark)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCustomExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                    .accessibilityIdentifier("create_custom_exercise_button")
                }
            }
            .sheet(isPresented: $showCustomExercise) {
                CustomExerciseView { exercise in
                    showCustomExercise = false
                    onSelect(exercise)
                }
            }
        }
        .alert("Exercise", isPresented: Binding(
            get: { vm.showAlert },
            set: { vm.showAlert = $0 }
        )) {
            Button("OK") { vm.showAlert = false }
        } message: {
            Text(vm.alertMessage ?? "")
        }
    }
}

private struct CustomExerciseView: View {
    @Environment(TemplateViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    let onCreate: (ExerciseDTO) -> Void
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("New Exercise")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)

                TextField("Exercise name", text: $name)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .accessibilityIdentifier("custom_exercise_name_field")

                Text("Custom exercises use a default icon for now. Sets and rest timers are still configured per workout.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                IroniqButton("Create") {
                    Task {
                        if let exercise = await vm.createCustomExercise(name: name) {
                            onCreate(exercise)
                        }
                    }
                }
                .accessibilityIdentifier("confirm_custom_exercise_button")
            }
            .padding(18)
            .background(Color.ironiqDark)
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Exercise", isPresented: Binding(
            get: { vm.showAlert },
            set: { vm.showAlert = $0 }
        )) {
            Button("OK") { vm.showAlert = false }
        } message: {
            Text(vm.alertMessage ?? "")
        }
    }
}

#Preview {
    ExercisePickerView(onSelect: { _ in })
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
}
