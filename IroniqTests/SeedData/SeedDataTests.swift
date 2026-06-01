import XCTest
@testable import Ironiq

final class SeedDataTests: XCTestCase {

    private func loadExercises() throws -> [SeedExerciseData] {
        // Unit tests run hosted inside the Ironiq app process — Bundle.main is the app bundle.
        try SeedDataService.loadExercises(from: .main)
    }

    func testSeedDataLoads() throws {
        XCTAssertNoThrow(try loadExercises())
    }

    func testMinimumExerciseCount() throws {
        let exercises = try loadExercises()
        XCTAssertGreaterThanOrEqual(exercises.count, 80, "Must have at least 80 exercises")
    }

    func testNoDuplicateIds() throws {
        let exercises = try loadExercises()
        let ids = exercises.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "All exercise IDs must be unique")
    }

    func testNoDuplicateNames() throws {
        let exercises = try loadExercises()
        let names = exercises.map { $0.name }
        XCTAssertEqual(names.count, Set(names).count, "All exercise names must be unique")
    }

    func testAllRequiredFieldsPresent() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            XCTAssertFalse(exercise.id.isEmpty, "\(exercise.name): id must not be empty")
            XCTAssertFalse(exercise.name.isEmpty, "Exercise name must not be empty")
            XCTAssertFalse(exercise.description.isEmpty, "\(exercise.name): description must not be empty")
            XCTAssertFalse(exercise.equipmentType.isEmpty, "\(exercise.name): equipmentType must not be empty")
            XCTAssertFalse(exercise.muscleGroups.isEmpty, "\(exercise.name): muscleGroups must not be empty")
            XCTAssertFalse(exercise.iconName.isEmpty, "\(exercise.name): iconName must not be empty")
        }
    }

    func testAllEquipmentTypesValid() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            XCTAssertNotNil(
                EquipmentType(rawValue: exercise.equipmentType),
                "\(exercise.name) has invalid equipmentType: '\(exercise.equipmentType)'"
            )
        }
    }

    func testAllMuscleGroupsValid() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            for group in exercise.muscleGroups {
                XCTAssertNotNil(
                    MuscleGroup(rawValue: group),
                    "\(exercise.name) has invalid muscleGroup: '\(group)'"
                )
            }
        }
    }

    func testDefaultLoggingTypesValid() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            if let defaultLoggingType = exercise.defaultLoggingType {
                XCTAssertNotNil(
                    SetLoggingType(rawValue: defaultLoggingType),
                    "\(exercise.name) has invalid defaultLoggingType: '\(defaultLoggingType)'"
                )
            }
        }
    }

    func testAllIdsAreValidUUIDs() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            XCTAssertNotNil(
                UUID(uuidString: exercise.id),
                "\(exercise.name) has invalid UUID: '\(exercise.id)'"
            )
        }
    }

    func testDescriptionLength() throws {
        let exercises = try loadExercises()
        for exercise in exercises {
            let wordCount = exercise.description.split(separator: " ").count
            XCTAssertGreaterThanOrEqual(wordCount, 20, "\(exercise.name): description too short (\(wordCount) words)")
            XCTAssertLessThanOrEqual(wordCount, 30, "\(exercise.name): description too long (\(wordCount) words)")
        }
    }

    func testExpectedExercisesPresent() throws {
        let exercises = try loadExercises()
        let names = Set(exercises.map { $0.name })

        let required = [
            "Deadlift", "Squat", "Flat Bench Press", "Overhead Press",
            "Pull Up", "Barbell Curl", "Tricep Pushdown", "Plank",
            "Hip Thrust", "Kettlebell Swing", "Turkish Get Up", "Dead Hang"
        ]

        for name in required {
            XCTAssertTrue(names.contains(name), "Expected exercise '\(name)' not found in seed data")
        }
    }

    func testBilateralDumbbellMovementsAreNotMarkedSingleHand() throws {
        let exercises = try loadExercises()
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })

        XCTAssertEqual(byName["Lateral Raise"]?.isSingleHand, false)
        XCTAssertEqual(byName["Bent Over Row"]?.isSingleHand, false)
    }

    func testDurationExercisesHaveDurationLoggingType() throws {
        let exercises = try loadExercises()
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })

        XCTAssertEqual(byName["Dead Hang"]?.defaultLoggingType, SetLoggingType.duration.rawValue)
        XCTAssertEqual(byName["Plank"]?.defaultLoggingType, SetLoggingType.duration.rawValue)
    }
}
