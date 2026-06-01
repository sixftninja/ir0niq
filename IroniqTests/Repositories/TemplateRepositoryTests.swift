import XCTest
import SwiftData
@testable import Ironiq

final class TemplateRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var exerciseRepo: ExerciseRepository!
    var templateRepo: TemplateRepository!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
        exerciseRepo = ExerciseRepository(modelContainer: container)
        templateRepo = TemplateRepository(modelContainer: container)
    }

    func testFetchAllEmpty() async throws {
        let templates = try await templateRepo.fetchAll()
        XCTAssertTrue(templates.isEmpty)
    }

    func testInsertEmptyTemplate() async throws {
        let id = try await templateRepo.insert(name: "Push Day", exercises: [])
        let templates = try await templateRepo.fetchAll()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.id, id)
        XCTAssertEqual(templates.first?.name, "Push Day")
        XCTAssertTrue(templates.first?.exercises.isEmpty ?? false)
    }

    func testInsertTemplateWithExercisesAndSets() async throws {
        let exerciseId = try await exerciseRepo.insert(
            id: UUID(),
            name: "Bench Press",
            exerciseDescription: "Chest press.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.chest],
            iconName: "bench-press",
            isCustom: false,
            isSeeded: false
        )

        let setInput = CreateTemplateSetInput(targetReps: 8, targetWeight: 80, restDuration: 90)
        let exerciseInput = CreateTemplateExerciseInput(
            exerciseId: exerciseId,
            equipmentTypeOverride: nil,
            sets: [setInput, setInput, setInput]
        )

        let templateId = try await templateRepo.insert(
            name: "Chest Day",
            exercises: [exerciseInput]
        )

        let template = try await templateRepo.fetchById(templateId)
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.exercises.count, 1)
        XCTAssertEqual(template?.exercises.first?.sets.count, 3)
        XCTAssertEqual(template?.exercises.first?.sets.first?.targetReps, 8)
    }

    func testFetchByIdNotFound() async throws {
        let result = try await templateRepo.fetchById(UUID())
        XCTAssertNil(result)
    }

    func testDelete() async throws {
        let id = try await templateRepo.insert(name: "To Delete", exercises: [])
        let countBefore = try await templateRepo.count()
        XCTAssertEqual(countBefore, 1)

        try await templateRepo.delete(id: id)
        let countAfter = try await templateRepo.count()
        XCTAssertEqual(countAfter, 0)
    }

    func testCount() async throws {
        let initial = try await templateRepo.count()
        XCTAssertEqual(initial, 0)
        _ = try await templateRepo.insert(name: "Template A", exercises: [])
        _ = try await templateRepo.insert(name: "Template B", exercises: [])
        let final = try await templateRepo.count()
        XCTAssertEqual(final, 2)
    }

    func testExerciseOrderPreserved() async throws {
        let ex1 = try await exerciseRepo.insert(
            id: UUID(), name: "Ex1", exerciseDescription: "Desc.",
            equipmentType: .barbell, isSingleHand: false, muscleGroups: [.chest],
            iconName: "ex1", isCustom: false, isSeeded: false
        )
        let ex2 = try await exerciseRepo.insert(
            id: UUID(), name: "Ex2", exerciseDescription: "Desc.",
            equipmentType: .dumbbell, isSingleHand: false, muscleGroups: [.back],
            iconName: "ex2", isCustom: false, isSeeded: false
        )

        let templateId = try await templateRepo.insert(
            name: "Full Body",
            exercises: [
                CreateTemplateExerciseInput(exerciseId: ex1, equipmentTypeOverride: nil, sets: []),
                CreateTemplateExerciseInput(exerciseId: ex2, equipmentTypeOverride: nil, sets: [])
            ]
        )

        let template = try await templateRepo.fetchById(templateId)
        XCTAssertEqual(template?.exercises.first?.exerciseId, ex1)
        XCTAssertEqual(template?.exercises.last?.exerciseId, ex2)
    }
}
