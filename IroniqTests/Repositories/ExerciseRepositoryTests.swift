import XCTest
import SwiftData
@testable import Ironiq

final class ExerciseRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var repository: ExerciseRepository!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
        repository = ExerciseRepository(modelContainer: container)
    }

    func testFetchAllEmpty() async throws {
        let exercises = try await repository.fetchAll()
        XCTAssertTrue(exercises.isEmpty)
    }

    func testInsertAndFetch() async throws {
        let id = try await repository.insert(
            id: UUID(),
            name: "Deadlift",
            exerciseDescription: "Hip hinge.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.back, .glutes, .hamstrings],
            iconName: "deadlift",
            isCustom: false,
            isSeeded: false
        )

        let exercises = try await repository.fetchAll()
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.id, id)
        XCTAssertEqual(exercises.first?.name, "Deadlift")
        XCTAssertEqual(exercises.first?.equipmentType, .barbell)
    }

    func testFetchById() async throws {
        let id = UUID()
        _ = try await repository.insert(
            id: id,
            name: "Squat",
            exerciseDescription: "Barbell squat.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.quadriceps, .glutes],
            iconName: "squat",
            isCustom: false,
            isSeeded: false
        )

        let dto = try await repository.fetchById(id)
        XCTAssertNotNil(dto)
        XCTAssertEqual(dto?.name, "Squat")
    }

    func testFetchByIdNotFound() async throws {
        let dto = try await repository.fetchById(UUID())
        XCTAssertNil(dto)
    }

    func testDelete() async throws {
        let id = try await repository.insert(
            id: UUID(),
            name: "Lunge",
            exerciseDescription: "Lunge.",
            equipmentType: .dumbbell,
            isSingleHand: false,
            muscleGroups: [.quadriceps],
            iconName: "lunge",
            isCustom: false,
            isSeeded: false
        )

        try await repository.delete(id: id)
        let exercises = try await repository.fetchAll()
        XCTAssertTrue(exercises.isEmpty)
    }

    func testCount() async throws {
        let initialCount = try await repository.count()
        XCTAssertEqual(initialCount, 0)

        for i in 1...3 {
            _ = try await repository.insert(
                id: UUID(),
                name: "Exercise \(i)",
                exerciseDescription: "Desc \(i).",
                equipmentType: .barbell,
                isSingleHand: false,
                muscleGroups: [.chest],
                iconName: "ex\(i)",
                isCustom: false,
                isSeeded: false
            )
        }

        let finalCount = try await repository.count()
        XCTAssertEqual(finalCount, 3)
    }

    func testSeedIfNeeded() async throws {
        let seedData = [
            SeedExerciseData(
                id: "00000001-0000-4000-8000-000000000000",
                name: "Deadlift",
                description: "Hip hinge.",
                equipmentType: "barbell",
                isSingleHand: false,
                muscleGroups: ["back", "glutes"],
                iconName: "deadlift"
            )
        ]

        let inserted = try await repository.seedIfNeeded(exercises: seedData)
        XCTAssertEqual(inserted, 1)

        // Second call should skip (already seeded)
        let insertedAgain = try await repository.seedIfNeeded(exercises: seedData)
        XCTAssertEqual(insertedAgain, 0)

        let count = try await repository.count()
        XCTAssertEqual(count, 1)
    }

    func testMuscleGroupsPreservedThroughRepository() async throws {
        let groups: [MuscleGroup] = [.chest, .triceps, .shoulders]
        _ = try await repository.insert(
            id: UUID(),
            name: "Bench Press",
            exerciseDescription: "Chest press.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: groups,
            iconName: "bench-press",
            isCustom: false,
            isSeeded: false
        )

        let dto = try await repository.fetchAll().first
        XCTAssertEqual(Set(dto?.muscleGroups ?? []), Set(groups))
    }
}
