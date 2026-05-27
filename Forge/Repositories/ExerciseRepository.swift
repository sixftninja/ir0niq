import Foundation
import SwiftData

// MARK: - Protocol

protocol ExerciseRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [ExerciseDTO]
    func fetchById(_ id: UUID) async throws -> ExerciseDTO?
    func insert(
        id: UUID,
        name: String,
        exerciseDescription: String,
        equipmentType: EquipmentType,
        isSingleHand: Bool,
        muscleGroups: [MuscleGroup],
        iconName: String,
        isCustom: Bool,
        isSeeded: Bool
    ) async throws -> UUID
    func delete(id: UUID) async throws
    func seedIfNeeded(exercises: [SeedExerciseData]) async throws -> Int
    func count() async throws -> Int
}

// MARK: - Implementation

@ModelActor
actor ExerciseRepository: ExerciseRepositoryProtocol {

    func fetchAll() throws -> [ExerciseDTO] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map { ExerciseDTO(from: $0) }
    }

    func fetchById(_ id: UUID) throws -> ExerciseDTO? {
        let predicate = #Predicate<Exercise> { $0.id == id }
        var descriptor = FetchDescriptor<Exercise>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map { ExerciseDTO(from: $0) }
    }

    func insert(
        id: UUID = UUID(),
        name: String,
        exerciseDescription: String,
        equipmentType: EquipmentType,
        isSingleHand: Bool,
        muscleGroups: [MuscleGroup],
        iconName: String,
        isCustom: Bool,
        isSeeded: Bool
    ) throws -> UUID {
        let exercise = Exercise(
            id: id,
            name: name,
            exerciseDescription: exerciseDescription,
            equipmentType: equipmentType,
            isSingleHand: isSingleHand,
            muscleGroups: muscleGroups,
            iconName: iconName,
            isCustom: isCustom,
            isSeeded: isSeeded
        )
        modelContext.insert(exercise)
        try modelContext.save()
        return exercise.id
    }

    func delete(id: UUID) throws {
        let predicate = #Predicate<Exercise> { $0.id == id }
        var descriptor = FetchDescriptor<Exercise>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }

    func seedIfNeeded(exercises: [SeedExerciseData]) throws -> Int {
        let seededCount = try modelContext.fetchCount(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.isSeeded == true })
        )
        guard seededCount == 0 else { return 0 }

        var inserted = 0
        for data in exercises {
            guard let equipmentType = EquipmentType(rawValue: data.equipmentType) else { continue }
            let muscleGroups = data.muscleGroups.compactMap { MuscleGroup(rawValue: $0) }
            let exercise = Exercise(
                id: UUID(uuidString: data.id) ?? UUID(),
                name: data.name,
                exerciseDescription: data.description,
                equipmentType: equipmentType,
                isSingleHand: data.isSingleHand,
                muscleGroups: muscleGroups,
                iconName: data.iconName,
                isCustom: false,
                isSeeded: true
            )
            modelContext.insert(exercise)
            inserted += 1
        }
        if inserted > 0 {
            try modelContext.save()
        }
        return inserted
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Exercise>())
    }
}
