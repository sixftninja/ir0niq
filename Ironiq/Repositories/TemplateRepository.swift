import Foundation
import SwiftData

// MARK: - Input types

struct CreateTemplateExerciseInput: Sendable {
    let exerciseId: UUID
    let equipmentTypeOverride: EquipmentType?
    let sets: [CreateTemplateSetInput]

    init(
        exerciseId: UUID,
        equipmentTypeOverride: EquipmentType? = nil,
        sets: [CreateTemplateSetInput]
    ) {
        self.exerciseId = exerciseId
        self.equipmentTypeOverride = equipmentTypeOverride
        self.sets = sets
    }
}

struct CreateTemplateSetInput: Sendable {
    let targetReps: Int?
    let targetWeight: Double?
    let targetDuration: TimeInterval?
    let restDuration: TimeInterval?
    let noteLabel: String?

    init(
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetDuration: TimeInterval? = nil,
        restDuration: TimeInterval? = nil,
        noteLabel: String? = nil
    ) {
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetDuration = targetDuration
        self.restDuration = restDuration
        self.noteLabel = noteLabel
    }
}

// MARK: - Protocol

protocol TemplateRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [TemplateDTO]
    func fetchById(_ id: UUID) async throws -> TemplateDTO?
    func insert(name: String, exercises: [CreateTemplateExerciseInput]) async throws -> UUID
    func update(id: UUID, name: String, exercises: [CreateTemplateExerciseInput]) async throws
    func appendExercise(templateId: UUID, exercise: CreateTemplateExerciseInput) async throws
    func delete(id: UUID) async throws
    func count() async throws -> Int
}

// MARK: - DTO construction helpers (within ModelActor context)

private func makeTemplateDTO(from model: Template) -> TemplateDTO {
    let exerciseDTOs = model.exercises
        .sorted { $0.order < $1.order }
        .map { makeTemplateExerciseDTO(from: $0) }
    return TemplateDTO(
        id: model.id,
        name: model.name,
        createdAt: model.createdAt,
        exercises: exerciseDTOs
    )
}

private func makeTemplateExerciseDTO(from model: TemplateExercise) -> TemplateExerciseDTO {
    let setDTOs = model.sets
        .sorted { $0.order < $1.order }
        .map { TemplateSetDTO(from: $0) }
    return TemplateExerciseDTO(
        id: model.id,
        exerciseId: model.exercise?.id ?? UUID(),
        exerciseName: model.exercise?.name ?? "",
        defaultLoggingType: model.exercise?.defaultLoggingType ?? .reps,
        order: model.order,
        equipmentTypeOverride: model.equipmentTypeOverrideEnum,
        sets: setDTOs
    )
}

// MARK: - Implementation

@ModelActor
actor TemplateRepository: TemplateRepositoryProtocol {

    func fetchAll() throws -> [TemplateDTO] {
        let descriptor = FetchDescriptor<Template>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map { makeTemplateDTO(from: $0) }
    }

    func fetchById(_ id: UUID) throws -> TemplateDTO? {
        let predicate = #Predicate<Template> { $0.id == id }
        var descriptor = FetchDescriptor<Template>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map { makeTemplateDTO(from: $0) }
    }

    func insert(name: String, exercises: [CreateTemplateExerciseInput]) throws -> UUID {
        let template = Template(name: name)
        modelContext.insert(template)

        for (index, exerciseInput) in exercises.enumerated() {
            let exerciseId = exerciseInput.exerciseId
            let exercisePredicate = #Predicate<Exercise> { $0.id == exerciseId }
            var exerciseDescriptor = FetchDescriptor<Exercise>(predicate: exercisePredicate)
            exerciseDescriptor.fetchLimit = 1
            guard let exercise = try modelContext.fetch(exerciseDescriptor).first else { continue }

            let templateExercise = TemplateExercise(
                exercise: exercise,
                order: index,
                equipmentTypeOverride: exerciseInput.equipmentTypeOverride
            )
            templateExercise.template = template
            modelContext.insert(templateExercise)

            for (setIndex, setInput) in exerciseInput.sets.enumerated() {
                let templateSet = TemplateSet(
                    order: setIndex,
                    targetReps: setInput.targetReps,
                    targetWeight: setInput.targetWeight,
                    targetDuration: setInput.targetDuration,
                    restDuration: setInput.restDuration,
                    noteLabel: setInput.noteLabel
                )
                templateSet.templateExercise = templateExercise
                modelContext.insert(templateSet)
            }
        }

        try modelContext.save()
        return template.id
    }

    func appendExercise(templateId: UUID, exercise exerciseInput: CreateTemplateExerciseInput) async throws {
        let templatePredicate = #Predicate<Template> { $0.id == templateId }
        var templateDescriptor = FetchDescriptor<Template>(predicate: templatePredicate)
        templateDescriptor.fetchLimit = 1
        guard let template = try modelContext.fetch(templateDescriptor).first else { return }

        let exerciseId = exerciseInput.exerciseId
        let exercisePredicate = #Predicate<Exercise> { $0.id == exerciseId }
        var exerciseDescriptor = FetchDescriptor<Exercise>(predicate: exercisePredicate)
        exerciseDescriptor.fetchLimit = 1
        guard let exercise = try modelContext.fetch(exerciseDescriptor).first else { return }

        let templateExercise = TemplateExercise(
            exercise: exercise,
            order: template.exercises.count,
            equipmentTypeOverride: exerciseInput.equipmentTypeOverride
        )
        templateExercise.template = template
        modelContext.insert(templateExercise)

        for (setIndex, setInput) in exerciseInput.sets.enumerated() {
            let templateSet = TemplateSet(
                order: setIndex,
                targetReps: setInput.targetReps,
                targetWeight: setInput.targetWeight,
                targetDuration: setInput.targetDuration,
                restDuration: setInput.restDuration,
                noteLabel: setInput.noteLabel
            )
            templateSet.templateExercise = templateExercise
            modelContext.insert(templateSet)
        }

        try modelContext.save()
    }

    func update(id: UUID, name: String, exercises exerciseInputs: [CreateTemplateExerciseInput]) async throws {
        let predicate = #Predicate<Template> { $0.id == id }
        var descriptor = FetchDescriptor<Template>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let template = try modelContext.fetch(descriptor).first else { return }

        template.name = name
        for exercise in Array(template.exercises) {
            modelContext.delete(exercise)
        }
        template.exercises.removeAll()

        for (index, exerciseInput) in exerciseInputs.enumerated() {
            let exerciseId = exerciseInput.exerciseId
            let exercisePredicate = #Predicate<Exercise> { $0.id == exerciseId }
            var exerciseDescriptor = FetchDescriptor<Exercise>(predicate: exercisePredicate)
            exerciseDescriptor.fetchLimit = 1
            guard let exercise = try modelContext.fetch(exerciseDescriptor).first else { continue }

            let templateExercise = TemplateExercise(
                exercise: exercise,
                order: index,
                equipmentTypeOverride: exerciseInput.equipmentTypeOverride
            )
            templateExercise.template = template
            modelContext.insert(templateExercise)

            for (setIndex, setInput) in exerciseInput.sets.enumerated() {
                let templateSet = TemplateSet(
                    order: setIndex,
                    targetReps: setInput.targetReps,
                    targetWeight: setInput.targetWeight,
                    targetDuration: setInput.targetDuration,
                    restDuration: setInput.restDuration,
                    noteLabel: setInput.noteLabel
                )
                templateSet.templateExercise = templateExercise
                modelContext.insert(templateSet)
            }
        }

        try modelContext.save()
    }

    func delete(id: UUID) throws {
        let predicate = #Predicate<Template> { $0.id == id }
        var descriptor = FetchDescriptor<Template>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Template>())
    }
}
