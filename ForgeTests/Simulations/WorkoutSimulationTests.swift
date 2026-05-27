import XCTest
@testable import Forge

/// Scripted end-to-end simulation tests covering full user journeys.
final class WorkoutSimulationTests: XCTestCase {

    var templateRepo: MockTemplateRepository!
    var sessionRepo: MockSessionRepository!
    var engine: SessionEngine!
    var templateId: UUID!
    var exerciseId: UUID!

    override func setUp() async throws {
        templateRepo = MockTemplateRepository()
        sessionRepo = MockSessionRepository()
        engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo
        )
        exerciseId = UUID()
        templateId = UUID()

        // Template: 1 exercise, 3 sets, 60s rest
        let template = TemplateDTO(
            id: templateId,
            name: "Simulation Template",
            createdAt: Date(),
            exercises: [
                TemplateExerciseDTO(
                    id: UUID(),
                    exerciseId: exerciseId,
                    exerciseName: "Squat",
                    order: 0,
                    equipmentTypeOverride: nil,
                    sets: [
                        TemplateSetDTO(id: UUID(), order: 0, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 60, noteLabel: nil),
                        TemplateSetDTO(id: UUID(), order: 1, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 60, noteLabel: nil),
                        TemplateSetDTO(id: UUID(), order: 2, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 60, noteLabel: nil)
                    ]
                )
            ]
        )
        await templateRepo.seed(template: template)
    }

    // MARK: - Simulation 1: Happy-path workout session

    func testSimulation_HappyPathWorkout() async throws {
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Do all 3 sets
        for i in 0..<3 {
            try await engine.beginCurrentSet()
            try await engine.tapRest(targetRestDuration: 60)
            try await engine.restEnded()
            try await engine.logCurrentSet(reps: 5, weight: 100 + Double(i))

            if i < 2 {
                try await engine.advanceToNext()  // to next set
            }
        }

        // End session — should have no unlogged sets
        let unlogged = try await engine.endSession()
        XCTAssertTrue(unlogged.isEmpty, "No sets should be unlogged in a happy-path session")

        try await engine.confirmEnd()
        let finalState = await engine.state
        if case .ended = finalState { } else {
            XCTFail("Session should be ended, got: \(finalState)")
        }

        // Verify all sets persisted as logged
        let context = await engine.sessionContext
        for set in context?.exercises[0].setContexts ?? [] {
            if case .logged = set.lifecycleState { } else {
                XCTFail("All sets should be logged")
            }
        }
    }

    // MARK: - Simulation 2: Forgot to tap Rest (nudge)

    func testSimulation_ForgotToTapRest_NudgeFires() async throws {
        let timerSystem = TimerSystem()
        let localEngine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            timerSystem: timerSystem
        )

        try await localEngine.selectTemplate(templateId)
        _ = try await localEngine.startSession()
        try await localEngine.beginCurrentSet()
        try await localEngine.tapRest(targetRestDuration: 0.2)

        // Give Task a moment to register the timer
        try await Task.sleep(for: .milliseconds(50))

        let context = await localEngine.sessionContext
        guard let setId = context?.currentSet?.sessionSetId else { XCTFail("No setId"); return }

        // Timer should be active at 2× rest = 0.4s
        let isActive = await timerSystem.isActive(.nudge(setId: setId))
        XCTAssertTrue(isActive, "Nudge timer should be scheduled")

        // After 2× rest fires, handle nudge (informational only)
        await localEngine.handleRestNudge(setId: setId)

        // Set should still be in resting state (nudge is informational)
        let contextAfter = await localEngine.sessionContext
        if case .resting = contextAfter?.currentSet?.lifecycleState { } else {
            XCTFail("Set should still be resting after nudge")
        }
    }

    // MARK: - Simulation 3: Forgot to log reps (enforcement)

    func testSimulation_ForgotToLogReps_EnforcedAtExerciseEnd() async throws {
        // Use template with 2 exercises
        let ex2Id = UUID()
        let twoExerciseTemplateId = UUID()
        let twoExerciseTemplate = TemplateDTO(
            id: twoExerciseTemplateId,
            name: "Two Exercise Template",
            createdAt: Date(),
            exercises: [
                TemplateExerciseDTO(
                    id: UUID(), exerciseId: exerciseId, exerciseName: "Squat", order: 0,
                    equipmentTypeOverride: nil,
                    sets: [
                        TemplateSetDTO(id: UUID(), order: 0, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 60, noteLabel: nil),
                        TemplateSetDTO(id: UUID(), order: 1, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 60, noteLabel: nil)
                    ]
                ),
                TemplateExerciseDTO(
                    id: UUID(), exerciseId: ex2Id, exerciseName: "Bench Press", order: 1,
                    equipmentTypeOverride: nil,
                    sets: [TemplateSetDTO(id: UUID(), order: 0, targetReps: 5, targetWeight: 80, targetDuration: nil, restDuration: 60, noteLabel: nil)]
                )
            ]
        )
        await templateRepo.seed(template: twoExerciseTemplate)

        try await engine.selectTemplate(twoExerciseTemplateId)
        _ = try await engine.startSession()

        // Log set 0 of exercise 0
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        try await engine.advanceToNext()  // to set 1

        // Do NOT log set 1 of exercise 0 — try to advance to exercise 1
        do {
            try await engine.advanceToNext()
            XCTFail("Should throw allSetsNotLogged when advancing to next exercise with unlogged sets")
        } catch SessionEngineError.allSetsNotLogged {
            // Expected
        }
    }

    // MARK: - Simulation 4: Session abandoned mid-way (incomplete save)

    func testSimulation_SessionAbandoned_SavedAsComplete() async throws {
        try await engine.selectTemplate(templateId)
        let sessionId = try await engine.startSession()

        // Complete set 0
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 3, weight: 80)
        try await engine.advanceToNext()  // → set 1

        // Begin set 1 but abandon without logging (in-progress)
        try await engine.beginCurrentSet()

        // End session — set 1 is in-progress, should appear in review list
        let unlogged = try await engine.endSession()
        XCTAssertFalse(unlogged.isEmpty, "In-progress set should appear in review before save")

        // Confirm end — marks in-progress set as notPerformed
        try await engine.confirmEnd()

        let status = await sessionRepo.sessionStatus(for: sessionId)
        XCTAssertEqual(status, .complete)
    }

    // MARK: - Simulation 5: Session ends at 3-hour max timer

    func testSimulation_MaxTimerAutoEnds() async throws {
        try await engine.selectTemplate(templateId)
        let sessionId = try await engine.startSession()
        let activeBefore = await engine.state
        if case .active = activeBefore { } else { XCTFail("Should be active"); return }

        await engine.handleMaxTimer()

        let stateAfter = await engine.state
        if case .ended(let id) = stateAfter {
            XCTAssertEqual(id, sessionId)
        } else {
            XCTFail("Session should auto-end after max timer, got: \(stateAfter)")
        }
    }

    // MARK: - Simulation 6: Late start (unrecorded sets)

    func testSimulation_LateStart_SetMarkedUnrecorded() async throws {
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Skip beginCurrentSet — log directly (late start scenario)
        try await engine.logCurrentSet(reps: 8, weight: 60)

        let context = await engine.sessionContext
        let set = context?.exercises[0].setContexts[0]
        XCTAssertTrue(set?.isUnrecorded == true, "Set logged without timer start is unrecorded")
        XCTAssertNil(set?.setTimerStart)
    }

    // MARK: - Simulation 7: Unplanned exercise with set count enforcement

    func testSimulation_UnplannedExercise_ZeroSetsRejected() async throws {
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        do {
            try await engine.addUnplannedExercise(exerciseId: UUID(), setCount: 0)
            XCTFail("setCount 0 should be rejected")
        } catch let error as SessionEngineError {
            if case .invalidTransition = error { } else { XCTFail("Wrong error: \(error)") }
        }
    }

    func testSimulation_UnplannedExercise_AddedSuccessfully() async throws {
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        let newExerciseId = UUID()
        try await engine.addUnplannedExercise(exerciseId: newExerciseId, setCount: 4)

        let context = await engine.sessionContext
        XCTAssertEqual(context?.exercises.count, 2)
        XCTAssertEqual(context?.exercises[1].exerciseId, newExerciseId)
        XCTAssertEqual(context?.exercises[1].setContexts.count, 4)
    }

    // MARK: - Simulation 8: Skip exercise (not performed)

    func testSimulation_SkipExercise_MarksNotPerformed() async throws {
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        try await engine.skipCurrentExercise()

        let context = await engine.sessionContext
        XCTAssertEqual(context?.exercises[0].status, .notPerformed)
        for set in context?.exercises[0].setContexts ?? [] {
            XCTAssertEqual(set.lifecycleState, .notPerformed)
        }
    }

    // MARK: - Pause/Resume cycle

    func testSimulation_PauseResumeCycle() async throws {
        try await engine.selectTemplate(templateId)
        let sessionId = try await engine.startSession()

        try await engine.pauseSession()
        let pausedState = await engine.state
        XCTAssertEqual(pausedState, .paused(sessionId: sessionId))

        try await engine.resumeSession()
        let resumedState = await engine.state
        XCTAssertEqual(resumedState, .active(sessionId: sessionId))

        // Should have created and closed a pause record
        let records = await sessionRepo.pauseRecords
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records.values.first?.endedAt)
    }
}
