import XCTest
import SwiftData
@testable import Ironiq

@MainActor
final class ExerciseModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    func testCreateAndFetchExercise() throws {
        let exercise = Exercise(
            name: "Deadlift",
            exerciseDescription: "Hip-hinge lift from the floor.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.back, .glutes, .hamstrings],
            iconName: "deadlift"
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Deadlift")
        XCTAssertEqual(fetched.first?.equipmentTypeEnum, .barbell)
        XCTAssertFalse(fetched.first?.isSingleHand ?? true)
        XCTAssertEqual(fetched.first?.muscleGroups, [.back, .glutes, .hamstrings])
    }

    func testExerciseEquipmentTypeRoundTrip() throws {
        let exercise = Exercise(
            name: "Cable Fly",
            exerciseDescription: "Cable chest fly.",
            equipmentType: .cable,
            isSingleHand: false,
            muscleGroups: [.chest],
            iconName: "cable-fly"
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>()).first
        XCTAssertEqual(fetched?.equipmentTypeEnum, .cable)
    }

    func testExerciseMuscleGroupsRoundTrip() throws {
        let groups: [MuscleGroup] = [.biceps, .forearms]
        let exercise = Exercise(
            name: "Hammer Curl",
            exerciseDescription: "Neutral grip curl.",
            equipmentType: .dumbbell,
            isSingleHand: false,
            muscleGroups: groups,
            iconName: "hammer-curl"
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>()).first
        XCTAssertEqual(Set(fetched?.muscleGroups ?? []), Set(groups))
    }

    func testExerciseIsSeededFlag() throws {
        let exercise = Exercise(
            name: "Squat",
            exerciseDescription: "Barbell squat.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.quadriceps, .glutes],
            iconName: "squat",
            isSeeded: true
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>()).first
        XCTAssertTrue(fetched?.isSeeded ?? false)
        XCTAssertFalse(fetched?.isCustom ?? true)
    }

    func testDeleteExercise() throws {
        let exercise = Exercise(
            name: "Lunge",
            exerciseDescription: "Lunge movement.",
            equipmentType: .dumbbell,
            isSingleHand: false,
            muscleGroups: [.quadriceps],
            iconName: "lunge"
        )
        context.insert(exercise)
        try context.save()

        context.delete(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertTrue(fetched.isEmpty)
    }

    func testUniqueIdPerExercise() throws {
        let ex1 = Exercise(
            name: "Pull Up",
            exerciseDescription: "Pull up.",
            equipmentType: .bodyweight,
            isSingleHand: false,
            muscleGroups: [.back],
            iconName: "pull-up"
        )
        let ex2 = Exercise(
            name: "Push Up",
            exerciseDescription: "Push up.",
            equipmentType: .bodyweight,
            isSingleHand: false,
            muscleGroups: [.chest],
            iconName: "push-up"
        )
        context.insert(ex1)
        context.insert(ex2)
        try context.save()

        XCTAssertNotEqual(ex1.id, ex2.id)
    }
}
