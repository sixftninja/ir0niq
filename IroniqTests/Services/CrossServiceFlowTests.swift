import XCTest
import SwiftData
@testable import Ironiq

// Phase 5: cross-service data flow — engine → repository → history.

final class CrossServiceFlowTests: XCTestCase {

    private var container: ModelContainer!
    private var templateRepo: TemplateRepository!
    private var sessionRepo: SessionRepository!
    private var exerciseRepo: ExerciseRepository!
    private var engine: SessionEngine!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemoryContainer()
        templateRepo = TemplateRepository(modelContainer: container)
        sessionRepo = SessionRepository(modelContainer: container)
        exerciseRepo = ExerciseRepository(modelContainer: container)
        engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo
        )
        // Seed exercises so templates can reference them.
        let service = SeedDataService(exerciseRepo: exerciseRepo)
        try await service.seedIfNeeded()
    }

    // Creating a template via the repo makes it appear in fetchAll.
    func testCreatedTemplateAppearsInFetchAll() async throws {
        let id = try await templateRepo.insert(name: "Back Day", exercises: [])
        let all = try await templateRepo.fetchAll()
        XCTAssertTrue(all.contains(where: { $0.id == id }), "Newly created template must appear in fetchAll")
    }

    // Deleting a template removes it from fetchAll.
    func testDeletedTemplateDisappearsFromFetchAll() async throws {
        let id = try await templateRepo.insert(name: "Leg Day", exercises: [])
        try await templateRepo.delete(id: id)
        let all = try await templateRepo.fetchAll()
        XCTAssertFalse(all.contains(where: { $0.id == id }), "Deleted template must not appear in fetchAll")
    }

    // A completed session logged through the engine appears in sessionRepo.fetchAll.
    func testCompletedSessionAppearsInHistory() async throws {
        let templateId = try await templateRepo.insert(
            name: "Push Day",
            exercises: [CreateTemplateExerciseInput(
                exerciseId: UUID(),
                sets: [CreateTemplateSetInput(targetReps: 10)]
            )]
        )

        try engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        guard case .active(let sessionId) = await engine.state else {
            XCTFail("Expected active state"); return
        }

        try await engine.requestEnd()
        try await engine.confirmEnd()

        let sessions = try await sessionRepo.fetchAll()
        XCTAssertTrue(sessions.contains(where: { $0.id == sessionId }), "Completed session must appear in history")
    }

    // Deleting a session via the repo removes it from fetchAll.
    func testDeletedSessionDisappearsFromHistory() async throws {
        let templateId = try await templateRepo.insert(
            name: "Chest Day",
            exercises: [CreateTemplateExerciseInput(
                exerciseId: UUID(),
                sets: [CreateTemplateSetInput(targetReps: 8)]
            )]
        )

        try engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        guard case .active(let sessionId) = await engine.state else {
            XCTFail("Expected active state"); return
        }

        try await engine.requestEnd()
        try await engine.confirmEnd()

        try await sessionRepo.delete(sessionId: sessionId)
        let sessions = try await sessionRepo.fetchAll()
        XCTAssertFalse(sessions.contains(where: { $0.id == sessionId }), "Deleted session must not appear in history")
    }

    // HistoryViewModel.loadSessions reflects sessions saved through the engine.
    func testHistoryViewModelReflectsEngineCompletedSession() async throws {
        let templateId = try await templateRepo.insert(
            name: "Shoulders",
            exercises: [CreateTemplateExerciseInput(
                exerciseId: UUID(),
                sets: [CreateTemplateSetInput(targetReps: 12)]
            )]
        )

        try engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        guard case .active(let sessionId) = await engine.state else {
            XCTFail("Expected active state"); return
        }

        try await engine.requestEnd()
        try await engine.confirmEnd()

        let appState = await AppState()
        let historyVM = await HistoryViewModel(sessionRepo: sessionRepo, appState: appState)
        await historyVM.loadSessions()
        let sessions = await historyVM.sessions
        XCTAssertTrue(sessions.contains(where: { $0.id == sessionId }), "HistoryViewModel must see the completed session")
    }
}
