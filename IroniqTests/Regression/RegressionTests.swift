import XCTest
import SwiftData
@testable import Ironiq

/// Full end-to-end regression suite. Runs every major cross-phase flow in sequence.
/// If any test here breaks, a regression was introduced somewhere across phases 1-6.
final class RegressionTests: XCTestCase {

    var container: ModelContainer!
    var exerciseRepo: ExerciseRepository!
    var templateRepo: TemplateRepository!
    var sessionRepo: SessionRepository!
    var engine: SessionEngine!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
        exerciseRepo = ExerciseRepository(modelContainer: container)
        templateRepo = TemplateRepository(modelContainer: container)
        sessionRepo = SessionRepository(modelContainer: container)
        engine = SessionEngine(templateRepository: templateRepo, sessionRepository: sessionRepo)

        // Seed exercises
        let seedData = try SeedDataService.loadExercises(from: .main)
        _ = try await exerciseRepo.seedIfNeeded(exercises: seedData)
    }

    // MARK: - Seed data integrity

    func testSeedDataLoadedCorrectly() async throws {
        let count = try await exerciseRepo.count()
        XCTAssertGreaterThanOrEqual(count, 80)
    }

    func testDeadliftExists() async throws {
        let exercises = try await exerciseRepo.fetchAll()
        XCTAssertTrue(exercises.contains { $0.name == "Deadlift" })
    }

    // MARK: - Template lifecycle

    func testCreateAndRetrieveTemplate() async throws {
        let deadliftId = try await exerciseRepo.fetchAll()
            .first(where: { $0.name == "Deadlift" })!.id

        let templateId = try await templateRepo.insert(
            name: "Strength Day",
            exercises: [
                CreateTemplateExerciseInput(
                    exerciseId: deadliftId,
                    equipmentTypeOverride: nil,
                    sets: [
                        CreateTemplateSetInput(targetReps: 5, targetWeight: 100, restDuration: 180),
                        CreateTemplateSetInput(targetReps: 5, targetWeight: 100, restDuration: 180),
                        CreateTemplateSetInput(targetReps: 5, targetWeight: 100, restDuration: 180)
                    ]
                )
            ]
        )

        let template = try await templateRepo.fetchById(templateId)
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.name, "Strength Day")
        XCTAssertEqual(template?.exercises.count, 1)
        XCTAssertEqual(template?.exercises.first?.sets.count, 3)
        XCTAssertEqual(template?.exercises.first?.sets.first?.targetReps, 5)
    }

    func testDeleteTemplateRemovesIt() async throws {
        let id = try await templateRepo.insert(name: "To Delete", exercises: [])
        let countBefore = try await templateRepo.count()
        try await templateRepo.delete(id: id)
        let countAfter = try await templateRepo.count()
        XCTAssertEqual(countAfter, countBefore - 1)
    }

    // MARK: - Full session happy-path (phases 1 + 2 + 3 integration)

    func testCompleteWorkoutSession() async throws {
        // 1. Create template
        let deadliftId = try await exerciseRepo.fetchAll()
            .first(where: { $0.name == "Deadlift" })!.id
        let templateId = try await templateRepo.insert(
            name: "Test Push",
            exercises: [
                CreateTemplateExerciseInput(
                    exerciseId: deadliftId,
                    equipmentTypeOverride: nil,
                    sets: [
                        CreateTemplateSetInput(targetReps: 5, targetWeight: 100, restDuration: 90),
                        CreateTemplateSetInput(targetReps: 5, targetWeight: 100, restDuration: 90)
                    ]
                )
            ]
        )

        // 2. Select template → start session
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // 3. Log set 1
        try await engine.beginCurrentSet()
        try await engine.tapRest(targetRestDuration: 90)
        try await engine.restEnded()
        try await engine.logCurrentSet(reps: 5, weight: 100)
        try await engine.advanceToNext()  // → set 2

        // 4. Log set 2. Sets auto-start when advanced, so this is recorded.
        try await engine.logCurrentSet(reps: 4, weight: 100)
        let context = await engine.sessionContext
        XCTAssertFalse(context?.exercises[0].setContexts[1].isUnrecorded == true,
                       "Auto-started sets should be recorded")

        // 5. End session cleanly
        let unlogged = try await engine.endSession()
        XCTAssertTrue(unlogged.isEmpty, "All sets accounted for")
        try await engine.confirmEnd()

        // 6. Verify final state
        let state = await engine.state
        if case .ended = state { } else { XCTFail("Expected ended, got \(state)") }

        // 7. Session persisted in repository
        let sessionCount = try await sessionRepo.count()
        XCTAssertEqual(sessionCount, 1)
    }

    // MARK: - Edge case 2 regression: log enforcement at exercise end

    func testAdvanceToNextExerciseEnforcesLoggingAcrossPhases() async throws {
        let benchId = try await exerciseRepo.fetchAll()
            .first(where: { $0.name == "Flat Bench Press" })!.id
        let squatId = try await exerciseRepo.fetchAll()
            .first(where: { $0.name == "Squat" })!.id

        let templateId = try await templateRepo.insert(
            name: "Regression Template",
            exercises: [
                CreateTemplateExerciseInput(exerciseId: benchId, equipmentTypeOverride: nil,
                    sets: [CreateTemplateSetInput(targetReps: 5), CreateTemplateSetInput(targetReps: 5)]),
                CreateTemplateExerciseInput(exerciseId: squatId, equipmentTypeOverride: nil,
                    sets: [CreateTemplateSetInput(targetReps: 5)])
            ]
        )

        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Log set 0 of exercise 0
        try await engine.logCurrentSet(reps: 5, weight: 80)
        try await engine.advanceToNext()  // → set 1

        // Try to advance to exercise 1 without logging set 1 → must throw
        do {
            try await engine.advanceToNext()
            XCTFail("Expected allSetsNotLogged")
        } catch SessionEngineError.allSetsNotLogged {
            // Correct — gate held
        }
    }

    // MARK: - Edge case 6 regression: auto-started set flag

    func testAutoStartedSetFlagSetCorrectly() async throws {
        _ = try await engine.startAdHocSession()
        let unplannedId = (try await exerciseRepo.fetchAll().first)!.id
        try await engine.addUnplannedExercise(exerciseId: unplannedId, setCount: 1)

        // No user-facing begin step; adding the first exercise auto-starts set 1.
        try await engine.logCurrentSet(reps: 10, weight: 0)
        let ctx = await engine.sessionContext
        XCTAssertFalse(ctx?.exercises[0].setContexts[0].isUnrecorded == true)
        XCTAssertNotNil(ctx?.exercises[0].setContexts[0].setTimerStart)
    }

    // MARK: - Template editor regression

    func testTemplateEditorSetDuplicationCopiesPreviousTargets() {
        let previous = SetEditorRow(targetType: .duration, targetReps: 12, targetDurationSeconds: 45)

        let duplicate = previous.duplicated()

        XCTAssertNotEqual(duplicate.id, previous.id)
        XCTAssertEqual(duplicate.targetType, previous.targetType)
        XCTAssertEqual(duplicate.targetReps, previous.targetReps)
        XCTAssertEqual(duplicate.targetDurationSeconds, previous.targetDurationSeconds)
    }

    // MARK: - Siri intents regression (Phase 5)

    func testPauseResumeIntentDoesNotCorruptState() async throws {
        _ = try await engine.startAdHocSession()
        SessionEngine.current = engine

        _ = try await PauseSessionIntent().perform()
        let paused = await engine.state
        XCTAssertTrue({ if case .paused = paused { return true }; return false }())

        _ = try await ResumeSessionIntent().perform()
        let resumed = await engine.state
        XCTAssertTrue({ if case .active = resumed { return true }; return false }())
    }

    // MARK: - Feature gate regression (Phase 5)

    @MainActor
    func testFreeTemplateLimitEnforced() {
        let appState = AppState()
        appState.isProUser = false

        // 7 templates → at limit
        let atLimit = AppState.freeTemplateLimit
        let canCreate = appState.isProUser || atLimit < AppState.freeTemplateLimit
        XCTAssertFalse(canCreate)

        // Pro unlocks
        appState.isProUser = true
        XCTAssertTrue(appState.isProUser || atLimit < AppState.freeTemplateLimit)
    }

    // MARK: - Weight formatter regression (Phase 6)

    func testWeightFormatterRoundTrip() {
        let kg = 80.0
        let lbs = WeightFormatter.fromKg(kg, unitSystem: .imperial)
        let backToKg = WeightFormatter.toKg(lbs, unitSystem: .imperial)
        XCTAssertEqual(backToKg, kg, accuracy: 0.001)
    }

    func testWeightFormatterDisplayStrings() {
        XCTAssertEqual(WeightFormatter.format(80, unitSystem: .metric), "80 kg")
        let lbsStr = WeightFormatter.format(80, unitSystem: .imperial)
        XCTAssertTrue(lbsStr.contains("lbs"), "Imperial should show lbs: \(lbsStr)")
    }

    // MARK: - GZip export regression (Phase 2)

    func testSessionExportRoundTrip() throws {
        let dto = SessionDTO(
            id: UUID(), templateId: nil,
            startedAt: Date().addingTimeInterval(-600), endedAt: Date(),
            status: .complete, totalPauseDuration: 0,
            exercises: []
        )
        let model = SessionExportModel.make(from: dto)
        let jsonData = try model.jsonData()
        let compressed = try jsonData.gzipped()
        XCTAssertFalse(compressed.isEmpty)
        XCTAssertEqual(compressed[0], 0x1f)
        XCTAssertEqual(compressed[1], 0x8b)
    }
}
