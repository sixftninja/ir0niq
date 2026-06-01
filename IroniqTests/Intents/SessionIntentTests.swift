import XCTest
@testable import Ironiq

final class SessionIntentTests: XCTestCase {

    var templateRepo: MockTemplateRepository!
    var sessionRepo: MockSessionRepository!
    var engine: SessionEngine!

    override func setUp() async throws {
        templateRepo = MockTemplateRepository()
        sessionRepo = MockSessionRepository()
        engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo
        )
        // Set as current so intents can access it
        SessionEngine.current = engine

        // Start an ad-hoc session so intents have something to act on
        _ = try await engine.startAdHocSession()
    }

    override func tearDown() async throws {
        await engine.reset()
        SessionEngine.current = nil
    }

    // MARK: - PauseSessionIntent

    func testPauseIntent_PausesActiveSession() async throws {
        let intent = PauseSessionIntent()
        _ = try await intent.perform()
        let state = await engine.state
        if case .paused = state { } else {
            XCTFail("Expected .paused state, got \(state)")
        }
    }

    func testPauseIntent_NoSession_ReturnsDialog() async throws {
        SessionEngine.current = nil
        let intent = PauseSessionIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)  // Returns dialog, does not crash
    }

    // MARK: - ResumeSessionIntent

    func testResumeIntent_ResumesAfterPause() async throws {
        try await engine.pauseSession()
        let intent = ResumeSessionIntent()
        _ = try await intent.perform()
        let state = await engine.state
        if case .active = state { } else {
            XCTFail("Expected .active state after resume, got \(state)")
        }
    }

    func testResumeIntent_WhenNotPaused_ReturnsDialog() async throws {
        // Engine is active, not paused — resume should fail gracefully
        let intent = ResumeSessionIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    // MARK: - EndSessionIntent

    func testEndIntent_EndsActiveSession() async throws {
        let intent = EndSessionIntent()
        _ = try await intent.perform()
        let state = await engine.state
        if case .ended = state { } else {
            XCTFail("Expected .ended state after end intent, got \(state)")
        }
    }

    // MARK: - NextSetIntent (ad-hoc session has no sets — should fail gracefully)

    func testNextSetIntent_NoSets_ReturnsDialog() async throws {
        let intent = NextSetIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)  // No crash, returns a dialog
    }

    // MARK: - SkipSetIntent (no exercises in ad-hoc session)

    func testSkipSetIntent_NoExercises_NoOp() async throws {
        let intent = SkipSetIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    // MARK: - PreviousSetIntent

    func testPreviousSetIntent_AtFirstSet_ReturnsDialog() async throws {
        let intent = PreviousSetIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }

    // MARK: - GoToPreviousSet engine method

    func testGoToPreviousSet_WithSessions() async throws {
        // Create a session with exercises and sets
        let templateId = UUID()
        let exerciseId = UUID()
        await templateRepo.seed(template: TemplateDTO(
            id: templateId,
            name: "Test",
            createdAt: Date(),
            exercises: [
                TemplateExerciseDTO(
                    id: UUID(), exerciseId: exerciseId, exerciseName: "Squat",
                    order: 0, equipmentTypeOverride: nil,
                    sets: [
                        TemplateSetDTO(order: 0, targetReps: 5),
                        TemplateSetDTO(order: 1, targetReps: 5)
                    ]
                )
            ]
        ))
        await engine.reset()
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Advance to set 1
        try await engine.beginCurrentSet()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        try await engine.advanceToNext()

        let contextBefore = await engine.sessionContext
        XCTAssertEqual(contextBefore?.currentSetIndex, 1)

        // Go back
        try await engine.goToPreviousSet()

        let contextAfter = await engine.sessionContext
        XCTAssertEqual(contextAfter?.currentSetIndex, 0, "Should move back to set 0")
    }

    func testGoToPreviousSet_AtFirstSet_Throws() async throws {
        let contextAtStart = await engine.sessionContext
        XCTAssertEqual(contextAtStart?.currentSetIndex, 0)

        do {
            try await engine.goToPreviousSet()
            XCTFail("Expected error when already at first set/exercise")
        } catch let error as SessionEngineError {
            if case .invalidTransition = error { } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Pause/Resume round-trip

    func testPauseResumeIntentRoundTrip() async throws {
        // Pause
        _ = try await PauseSessionIntent().perform()
        let paused = await engine.state
        XCTAssertTrue({ if case .paused = paused { return true }; return false }())

        // Resume
        _ = try await ResumeSessionIntent().perform()
        let active = await engine.state
        XCTAssertTrue({ if case .active = active { return true }; return false }())
    }
}
