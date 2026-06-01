import XCTest
@testable import Ironiq

final class SessionEngineTests: XCTestCase {

    var engine: SessionEngine!
    var templateRepo: MockTemplateRepository!
    var sessionRepo: MockSessionRepository!

    // A shared template with 1 exercise and 2 sets for most tests
    var testTemplateId: UUID!
    var testExerciseId: UUID!

    override func setUp() async throws {
        templateRepo = MockTemplateRepository()
        sessionRepo = MockSessionRepository()
        engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo
        )

        testExerciseId = UUID()
        testTemplateId = UUID()
        let template = TemplateDTO(
            id: testTemplateId,
            name: "Test Template",
            createdAt: Date(),
            exercises: [
                TemplateExerciseDTO(
                    id: UUID(),
                    exerciseId: testExerciseId,
                    exerciseName: "Deadlift",
                    order: 0,
                    equipmentTypeOverride: nil,
                    sets: [
                        TemplateSetDTO(id: UUID(), order: 0, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 120, noteLabel: nil),
                        TemplateSetDTO(id: UUID(), order: 1, targetReps: 5, targetWeight: 100, targetDuration: nil, restDuration: 120, noteLabel: nil)
                    ]
                )
            ]
        )
        await templateRepo.seed(template: template)
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() async {
        let state = await engine.state
        XCTAssertEqual(state, .idle)
    }

    // MARK: - State transitions

    func testSelectTemplate() async throws {
        try await engine.selectTemplate(testTemplateId)
        let state = await engine.state
        XCTAssertEqual(state, .templateSelected(templateId: testTemplateId))
    }

    func testSelectTemplateFromNonIdleThrows() async throws {
        try await engine.selectTemplate(testTemplateId)
        do {
            try await engine.selectTemplate(testTemplateId)
            XCTFail("Expected error")
        } catch let error as SessionEngineError {
            if case .invalidTransition = error { } else { XCTFail("Wrong error: \(error)") }
        }
    }

    func testStartSession() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()
        let state = await engine.state
        XCTAssertEqual(state, .active(sessionId: sessionId))
        let sessionCount = try await sessionRepo.count()
        XCTAssertEqual(sessionCount, 1)
    }

    func testStartSessionCreatesExercisesAndSets() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        let exercises = await sessionRepo.sessionExercises
        let sets = await sessionRepo.sessionSets
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(sets.count, 2)
    }

    func testStartSessionPreservesTemplateSetCounts() async throws {
        let templateId = UUID()
        let exercises = (0..<5).map { exerciseIndex in
            TemplateExerciseDTO(
                id: UUID(),
                exerciseId: UUID(),
                exerciseName: "Exercise \(exerciseIndex + 1)",
                order: exerciseIndex,
                equipmentTypeOverride: nil,
                sets: (0..<3).map { setIndex in
                    TemplateSetDTO(order: setIndex, restDuration: 30)
                }
            )
        }
        await templateRepo.seed(template: TemplateDTO(
            id: templateId,
            name: "Five by Three",
            createdAt: Date(),
            exercises: exercises
        ))

        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        let context = await engine.sessionContext
        XCTAssertEqual(context?.exercises.count, 5)
        XCTAssertEqual(context?.exercises.map(\.setContexts.count), [3, 3, 3, 3, 3])
    }

    func testPauseAndResume() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()

        try await engine.pauseSession()
        let pausedState = await engine.state
        XCTAssertEqual(pausedState, .paused(sessionId: sessionId))

        try await engine.resumeSession()
        let resumedState = await engine.state
        XCTAssertEqual(resumedState, .active(sessionId: sessionId))
    }

    func testEndSession() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()
        _ = try await engine.endSession()
        let state = await engine.state
        XCTAssertEqual(state, .ending(sessionId: sessionId))
    }

    func testConfirmEnd() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()
        _ = try await engine.endSession()
        try await engine.confirmEnd()
        let state = await engine.state
        XCTAssertEqual(state, .ended(sessionId: sessionId))
    }

    func testCanStartNewSessionAfterConfirmEnd() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        _ = try await engine.endSession()
        try await engine.confirmEnd()

        let newSessionId = try await engine.startAdHocSession()
        let state = await engine.state

        XCTAssertEqual(state, .active(sessionId: newSessionId))
    }

    func testCanStartSameTemplateAgainAfterConfirmEnd() async throws {
        try await engine.selectTemplate(testTemplateId)
        let firstSessionId = try await engine.startSession()
        _ = try await engine.endSession()
        try await engine.confirmEnd()

        try await engine.selectTemplate(testTemplateId)
        let secondSessionId = try await engine.startSession()
        let state = await engine.state

        XCTAssertNotEqual(firstSessionId, secondSessionId)
        XCTAssertEqual(state, .active(sessionId: secondSessionId))
    }

    func testStartSessionContinuesWhenHealthKitStartFails() async throws {
        let healthKit = MockHealthKitService()
        healthKit.set(startWorkoutError: HealthKitError.authorizationDenied)
        let localEngine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            healthKitService: healthKit
        )

        try await localEngine.selectTemplate(testTemplateId)
        let sessionId = try await localEngine.startSession()
        let state = await localEngine.state
        XCTAssertEqual(state, .active(sessionId: sessionId))
        let sessionCount = try await sessionRepo.count()
        XCTAssertEqual(sessionCount, 1)
        let context = await localEngine.sessionContext
        XCTAssertNotNil(context)
    }

    func testConfirmEndContinuesWhenHealthKitEndFails() async throws {
        let healthKit = MockHealthKitService()
        healthKit.set(endWorkoutError: HealthKitError.saveFailed("boom"))
        let localEngine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            healthKitService: healthKit
        )

        try await localEngine.selectTemplate(testTemplateId)
        _ = try await localEngine.startSession()
        _ = try await localEngine.endSession()

        try await localEngine.confirmEnd()
        if case .ended = await localEngine.state {
            // Expected
        } else {
            XCTFail("Expected ended state")
        }
    }

    func testConfirmEndContinuesWhenICloudExportFails() async throws {
        let iCloud = MockiCloudService()
        await iCloud.set(errorToThrow: iCloudError.writeFailed("boom"))
        let localEngine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            iCloudService: iCloud
        )

        try await localEngine.selectTemplate(testTemplateId)
        _ = try await localEngine.startSession()
        _ = try await localEngine.endSession()

        try await localEngine.confirmEnd()
        if case .ended = await localEngine.state {
            // Expected
        } else {
            XCTFail("Expected ended state")
        }
    }

    func testCancelEnd() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()
        _ = try await engine.endSession()
        try await engine.cancelEnd()
        let state = await engine.state
        XCTAssertEqual(state, .active(sessionId: sessionId))
    }

    func testReset() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        await engine.reset()
        let state = await engine.state
        XCTAssertEqual(state, .idle)
    }

    // MARK: - Set lifecycle

    func testSetLifecyclePendingToInProgress() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.beginCurrentSet()
        let context = await engine.sessionContext
        guard let set = context?.currentSet else { XCTFail("No current set"); return }
        if case .inProgress = set.lifecycleState { } else {
            XCTFail("Expected inProgress, got \(set.lifecycleState)")
        }
        XCTAssertNotNil(set.setTimerStart)
    }

    func testSetLifecycleInProgressToResting() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.beginCurrentSet()
        try await engine.tapRest(targetRestDuration: 60)
        let context = await engine.sessionContext
        guard let set = context?.currentSet else { XCTFail("No current set"); return }
        if case .resting = set.lifecycleState { } else {
            XCTFail("Expected resting, got \(set.lifecycleState)")
        }
        XCTAssertNotNil(set.restStart)
    }

    func testSetLifecycleRestingToAwaitingInput() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.beginCurrentSet()
        try await engine.tapRest(targetRestDuration: 60)
        try await engine.restEnded()
        let context = await engine.sessionContext
        guard let set = context?.currentSet else { XCTFail("No current set"); return }
        XCTAssertEqual(set.lifecycleState, .awaitingInput)
        XCTAssertNotNil(set.restEnd)
    }

    func testLogCurrentSet() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.beginCurrentSet()
        try await engine.tapRest(targetRestDuration: 60)
        try await engine.restEnded()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        let context = await engine.sessionContext
        guard let set = context?.currentSet else { XCTFail("No current set"); return }
        if case .logged(let reps, _, let weight) = set.lifecycleState {
            XCTAssertEqual(reps, 5)
            XCTAssertEqual(weight, 100)
        } else {
            XCTFail("Expected logged, got \(set.lifecycleState)")
        }
    }

    func testAdvanceToNextSet() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        // Log set 0
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        let contextBefore = await engine.sessionContext
        XCTAssertEqual(contextBefore?.currentSetIndex, 0)

        try await engine.advanceToNext()
        let contextAfter = await engine.sessionContext
        XCTAssertEqual(contextAfter?.currentSetIndex, 1)
    }

    func testSkipCurrentSetMarksOnlyCurrentSetNotPerformed() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        try await engine.skipCurrentSet()

        let context = await engine.sessionContext
        XCTAssertEqual(context?.currentSetIndex, 1)
        let firstSet = context?.exercises[0].setContexts[0]
        let secondSet = context?.exercises[0].setContexts[1]
        XCTAssertEqual(firstSet?.lifecycleState, .notPerformed)
        XCTAssertEqual(secondSet?.lifecycleState, .pending)
    }

    // MARK: - Edge Case 1: Nudge at 2× rest time

    func testNudgeTimerScheduledOnTapRest() async throws {
        let timerSystem = TimerSystem()
        let localEngine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            timerSystem: timerSystem
        )

        try await localEngine.selectTemplate(testTemplateId)
        _ = try await localEngine.startSession()
        try await localEngine.beginCurrentSet()
        try await localEngine.tapRest(targetRestDuration: 30)

        // Give the Task a moment to schedule the timer
        try await Task.sleep(for: .milliseconds(50))

        let context = await localEngine.sessionContext
        guard let setId = context?.currentSet?.sessionSetId else { XCTFail("No set"); return }
        let isActive = await timerSystem.isActive(.nudge(setId: setId))
        XCTAssertTrue(isActive, "Nudge timer should be scheduled at 2× rest duration")
    }

    // MARK: - Edge Case 2: Log enforcement at exercise end

    func testAdvanceToNextExerciseEnforcesLogging() async throws {
        // Template has 1 exercise, 2 sets
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        // Log set 0
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        try await engine.advanceToNext()  // advance to set 1

        // Do NOT log set 1
        // Try to advance to "next exercise" — should throw allSetsNotLogged
        do {
            try await engine.advanceToNext()
            XCTFail("Expected allSetsNotLogged error")
        } catch SessionEngineError.allSetsNotLogged {
            // Expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Edge Case 3: Review before saving

    func testEndSessionReturnsUnloggedSets() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        // Begin set 0 (in-progress) without logging
        try await engine.beginCurrentSet()

        let unlogged = try await engine.endSession()
        XCTAssertEqual(unlogged.count, 1, "Should have 1 in-progress set")
        XCTAssertEqual(unlogged.first?.exerciseId, testExerciseId)
    }

    func testEndSessionWithNoUnloggedSets() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        // Log all sets
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        try await engine.advanceToNext()
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)

        let unlogged = try await engine.endSession()
        XCTAssertTrue(unlogged.isEmpty)
    }

    // MARK: - Edge Case 4: Auto-save (repository called on log)

    func testLogSetPersistsToRepository() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 8, weight: 80)

        let context = await engine.sessionContext
        guard let setId = context?.exercises[0].setContexts[0].sessionSetId else {
            XCTFail("No set ID"); return
        }
        let record = await sessionRepo.setRecord(for: setId)
        XCTAssertEqual(record?.status, .logged)
        XCTAssertEqual(record?.reps, 8)
        XCTAssertEqual(record?.weight, 80)
    }

    func testLogDurationSetPersistsToRepository() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        try await engine.logCurrentSet(reps: nil, durationSeconds: 45, weight: 20)

        let context = await engine.sessionContext
        guard let setId = context?.exercises[0].setContexts[0].sessionSetId else {
            XCTFail("No set ID"); return
        }
        let record = await sessionRepo.setRecord(for: setId)
        XCTAssertEqual(record?.status, .logged)
        XCTAssertNil(record?.reps)
        XCTAssertEqual(record?.durationSeconds, 45)
        XCTAssertEqual(record?.weight, 20)
    }

    // MARK: - Edge Case 5: 3-hour max / idle auto-end (handler test)

    func testHandleMaxTimerEndsSession() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()

        await engine.handleMaxTimer()

        // After max timer, session should be ended
        let state = await engine.state
        if case .ended(let id) = state {
            XCTAssertEqual(id, sessionId)
        } else {
            XCTFail("Expected ended state, got \(state)")
        }
    }

    func testHandleIdleTimeoutEndsSession() async throws {
        try await engine.selectTemplate(testTemplateId)
        let sessionId = try await engine.startSession()

        await engine.handleIdleTimeout()

        let state = await engine.state
        if case .ended(let id) = state {
            XCTAssertEqual(id, sessionId)
        } else {
            XCTFail("Expected ended state, got \(state)")
        }
    }

    // MARK: - Edge Case 6: Auto-started set timing

    func testLogWithoutManualBeginUsesAutoStartedTimer() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()
        // There is no user-facing begin action; set 1 is already in progress.
        try await engine.logCurrentSet(reps: 10, weight: 50)

        let context = await engine.sessionContext
        let set = context?.exercises[0].setContexts[0]
        XCTAssertFalse(set?.isUnrecorded == true, "Auto-started set should be recorded")
        XCTAssertNotNil(set?.setTimerStart)
    }

    // MARK: - Edge Case 7: Set count enforcement for unplanned exercises

    func testAddUnplannedExerciseWithZeroSetsThrows() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        do {
            try await engine.addUnplannedExercise(exerciseId: UUID(), setCount: 0)
            XCTFail("Expected error for setCount < 1")
        } catch let error as SessionEngineError {
            if case .invalidTransition = error { } else { XCTFail("Wrong error: \(error)") }
        }
    }

    func testAddUnplannedExerciseWithValidSetCount() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        let exerciseId = UUID()
        try await engine.addUnplannedExercise(exerciseId: exerciseId, setCount: 3)

        let context = await engine.sessionContext
        XCTAssertEqual(context?.exercises.count, 2)  // original + unplanned
        XCTAssertEqual(context?.exercises[1].setContexts.count, 3)
        XCTAssertEqual(context?.exercises[1].exerciseId, exerciseId)
    }

    func testAddUnplannedExerciseUsesConfiguredSetPlanAndAppendsToTemplate() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        let exerciseId = UUID()
        try await engine.addUnplannedExercise(
            exerciseId: exerciseId,
            exerciseName: "Incline Press",
            sets: [
                CreateTemplateSetInput(restDuration: 45),
                CreateTemplateSetInput(restDuration: 60)
            ]
        )

        let context = await engine.sessionContext
        XCTAssertEqual(context?.exercises[1].exerciseName, "Incline Press")
        XCTAssertEqual(context?.exercises[1].setContexts.count, 2)
        XCTAssertEqual(context?.exercises[1].setContexts.map(\.targetRestDuration), [45, 60])
        let appended = await templateRepo.appendedExercises[testTemplateId]
        XCTAssertEqual(appended?.first?.sets.map(\.restDuration), [45, 60])
    }

    // MARK: - Edge Case 8: Not Performed for skipped exercises

    func testSkipCurrentExercise() async throws {
        try await engine.selectTemplate(testTemplateId)
        _ = try await engine.startSession()

        try await engine.skipCurrentExercise()

        let context = await engine.sessionContext
        let exercise = context?.exercises[0]
        XCTAssertEqual(exercise?.status, .notPerformed)
        for set in exercise?.setContexts ?? [] {
            XCTAssertEqual(set.lifecycleState, .notPerformed)
        }
    }

    // MARK: - Ad-hoc session

    func testStartAdHocSession() async throws {
        let sessionId = try await engine.startAdHocSession()
        let state = await engine.state
        XCTAssertEqual(state, .active(sessionId: sessionId))
        let context = await engine.sessionContext
        XCTAssertTrue(context?.exercises.isEmpty == true)
    }
}
