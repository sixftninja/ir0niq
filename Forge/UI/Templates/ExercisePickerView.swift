import SwiftUI

struct ExercisePickerView: View {
    @Environment(TemplateViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ExerciseDTO) -> Void

    @State private var searchText = ""

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
                            Button {
                                onSelect(exercise)
                            } label: {
                                ExerciseRowView(exercise: exercise)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("exercise_\(exercise.name.replacingOccurrences(of: " ", with: "_"))")
                        }
                    }
                    .listRowBackground(Color(white: 0.1))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.forgeDark)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ExercisePickerView(onSelect: { _ in })
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
}
