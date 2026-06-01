import XCTest
import SwiftData
@testable import Ironiq

@MainActor
final class SessionModelTests: XCTestCase {

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

    // MARK: - Session

    func testCreateSession() throws {
        let session = Session(startedAt: Date())
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.status, .incomplete)
        XCTAssertEqual(fetched.first?.totalPauseDuration, 0)
    }

    func testSessionStatusRoundTrip() throws {
        let session = Session(status: .complete)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>()).first
        XCTAssertEqual(fetched?.status, .complete)
    }

    // MARK: - SessionExercise

    func testSessionExerciseRelationship() throws {
        let exercise = Exercise(
            name: "Bench Press",
            exerciseDescription: "Chest press.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.chest],
            iconName: "bench-press"
        )
        context.insert(exercise)

        let session = Session()
        context.insert(session)

        let sessionExercise = SessionExercise(exercise: exercise, order: 0, executionOrder: 0)
        sessionExercise.session = session
        context.insert(sessionExercise)

        try context.save()

        let fetchedSessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetchedSessions.first?.exercises.count, 1)
        XCTAssertEqual(fetchedSessions.first?.exercises.first?.exercise?.name, "Bench Press")
    }

    // MARK: - SessionSet

    func testSessionSetLifecycle() throws {
        let exercise = Exercise(
            name: "Squat",
            exerciseDescription: "Squat.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.quadriceps],
            iconName: "squat"
        )
        context.insert(exercise)

        let sessionExercise = SessionExercise(exercise: exercise, order: 0, executionOrder: 0)
        context.insert(sessionExercise)

        let set = SessionSet(order: 0)
        set.sessionExercise = sessionExercise
        set.status = .logged
        set.reps = 5
        set.weight = 100.0
        context.insert(set)

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SessionSet>()).first
        XCTAssertEqual(fetched?.status, .logged)
        XCTAssertEqual(fetched?.reps, 5)
        XCTAssertEqual(fetched?.weight, 100.0)
        XCTAssertFalse(fetched?.isUnrecorded ?? true)
    }

    func testSessionSetTimerDuration() throws {
        let start = Date()
        let end = start.addingTimeInterval(45)
        let set = SessionSet(order: 0)
        set.setTimerStart = start
        set.setTimerEnd = end
        context.insert(set)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SessionSet>()).first
        let setDuration = try XCTUnwrap(fetched?.setDuration)
        XCTAssertEqual(setDuration, 45, accuracy: 0.001)
    }

    func testSessionSetRestDuration() throws {
        let restStart = Date()
        let restEnd = restStart.addingTimeInterval(90)
        let set = SessionSet(order: 0)
        set.restStart = restStart
        set.restEnd = restEnd
        context.insert(set)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SessionSet>()).first
        let restDuration = try XCTUnwrap(fetched?.restDuration)
        XCTAssertEqual(restDuration, 90, accuracy: 0.001)
    }

    // MARK: - PauseRecord

    func testPauseRecord() throws {
        let session = Session()
        context.insert(session)

        let pauseStart = Date()
        let pauseEnd = pauseStart.addingTimeInterval(120)
        let record = PauseRecord(session: session, startedAt: pauseStart)
        record.endedAt = pauseEnd
        context.insert(record)

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PauseRecord>()).first
        let duration = try XCTUnwrap(fetched?.duration)
        XCTAssertEqual(duration, 120, accuracy: 0.001)
    }

    // MARK: - Cascade delete

    func testSessionCascadeDeletesExercises() throws {
        let exercise = Exercise(
            name: "Row",
            exerciseDescription: "Row.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.back],
            iconName: "row"
        )
        context.insert(exercise)

        let session = Session()
        context.insert(session)

        let sessionExercise = SessionExercise(exercise: exercise, order: 0, executionOrder: 0)
        sessionExercise.session = session
        context.insert(sessionExercise)

        try context.save()
        context.delete(session)
        try context.save()

        let exercisesLeft = try context.fetch(FetchDescriptor<SessionExercise>())
        XCTAssertTrue(exercisesLeft.isEmpty, "SessionExercise should be cascade-deleted with session")
    }

    // MARK: - Template

    func testTemplateWithExercises() throws {
        let template = Template(name: "Push Day")
        context.insert(template)

        let exercise = Exercise(
            name: "Bench Press",
            exerciseDescription: "Chest press.",
            equipmentType: .barbell,
            isSingleHand: false,
            muscleGroups: [.chest],
            iconName: "bench-press"
        )
        context.insert(exercise)

        let templateExercise = TemplateExercise(exercise: exercise, order: 0)
        templateExercise.template = template
        context.insert(templateExercise)

        let templateSet = TemplateSet(order: 0, targetReps: 8, targetWeight: 80, restDuration: 90)
        templateSet.templateExercise = templateExercise
        context.insert(templateSet)

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Template>()).first
        XCTAssertEqual(fetched?.exercises.count, 1)
        XCTAssertEqual(fetched?.exercises.first?.sets.count, 1)
        XCTAssertEqual(fetched?.exercises.first?.sets.first?.targetReps, 8)
    }
}
