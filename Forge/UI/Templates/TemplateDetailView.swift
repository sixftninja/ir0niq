import SwiftUI

struct TemplateDetailView: View {
    let template: TemplateDTO
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(TemplateViewModel.self) private var templateVM
    @State private var showEditor = false

    var body: some View {
        List {
            ForEach(template.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                Section(exercise.exerciseName) {
                    ForEach(exercise.sets.sorted(by: { $0.order < $1.order })) { set in
                        setRow(set)
                    }
                }
                .listRowBackground(Color(white: 0.1))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.forgeDark)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
                    .accessibilityIdentifier("edit_template_button")
            }
        }
        .safeAreaInset(edge: .bottom) {
            startButton
        }
        .sheet(isPresented: $showEditor) {
            TemplateEditorView(existingTemplate: template)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func setRow(_ set: TemplateSetDTO) -> some View {
        HStack {
            Text("Set \(set.order + 1)")
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            if let reps = set.targetReps {
                Text("\(reps) reps")
                    .foregroundStyle(.white)
            }
            if let weight = set.targetWeight {
                Text("· \(weight, specifier: "%.0f") kg")
                    .foregroundStyle(.white.opacity(0.7))
            }
            if let rest = set.restDuration {
                Text("· \(Int(rest))s rest")
                    .foregroundStyle(Color.forgeOrange.opacity(0.8))
            }
        }
        .font(.subheadline)
    }

    private var startButton: some View {
        Button {
            Task {
                await sessionVM.selectTemplate(template.id)
                await sessionVM.startSession()
            }
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.forgeOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .accessibilityIdentifier("start_template_button")
        .background(Color.forgeDark)
    }
}

extension TemplateExerciseDTO: Hashable {
    public static func == (l: TemplateExerciseDTO, r: TemplateExerciseDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
extension TemplateSetDTO: Hashable {
    public static func == (l: TemplateSetDTO, r: TemplateSetDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

#Preview {
    NavigationStack {
        TemplateDetailView(template: TemplateDTO(
            id: UUID(),
            name: "Push Day",
            createdAt: Date(),
            exercises: [
                TemplateExerciseDTO(
                    id: UUID(), exerciseId: UUID(), exerciseName: "Flat Bench Press",
                    order: 0, equipmentTypeOverride: nil,
                    sets: [
                        TemplateSetDTO(order: 0, targetReps: 8, targetWeight: 80, restDuration: 90),
                        TemplateSetDTO(order: 1, targetReps: 8, targetWeight: 80, restDuration: 90),
                        TemplateSetDTO(order: 2, targetReps: 8, targetWeight: 80, restDuration: 90)
                    ]
                )
            ]
        ))
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
    }
}
