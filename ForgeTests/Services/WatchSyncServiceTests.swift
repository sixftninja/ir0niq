import XCTest
@testable import Forge

private actor MessageTracker {
    private(set) var lastMessage: WatchSetCompletionMessage?
    func record(_ msg: WatchSetCompletionMessage) { lastMessage = msg }
}

final class WatchSyncServiceTests: XCTestCase {

    var mock: MockWatchSyncService!

    override func setUp() async throws {
        mock = MockWatchSyncService()
    }

    func testActivationSetsFlag() async {
        let activatedBefore = await mock.activated
        XCTAssertFalse(activatedBefore)
        await mock.activate()
        let activatedAfter = await mock.activated
        XCTAssertTrue(activatedAfter)
    }

    func testIsReachableDefault() async {
        let reachable = await mock.isReachable
        XCTAssertTrue(reachable)
    }

    func testSendSessionState() async {
        let message = WatchSessionStateMessage(
            sessionId: UUID().uuidString,
            engineState: "active",
            exerciseName: "Deadlift",
            setNumber: 1,
            totalSets: 3,
            setStatus: "inProgress"
        )
        await mock.sendSessionState(message)
        let sent = await mock.sentStates
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.engineState, "active")
        XCTAssertEqual(sent.first?.setNumber, 1)
    }

    func testOnSetCompletionRegistered() async throws {
        let expectation = XCTestExpectation(description: "Completion handler called")
        let tracker = MessageTracker()

        await mock.onSetCompletion { msg in
            Task { await tracker.record(msg) }
            expectation.fulfill()
        }

        let testMessage = WatchSetCompletionMessage(
            sessionId: UUID().uuidString,
            setId: UUID().uuidString,
            reps: 5,
            weight: 100
        )
        await mock.simulateSetCompletion(testMessage)
        await fulfillment(of: [expectation], timeout: 1.0)

        let received = await tracker.lastMessage
        XCTAssertEqual(received?.reps, 5)
        XCTAssertEqual(received?.weight, 100)
    }

    func testMultipleStateMessages() async {
        let states = ["active", "paused", "active", "ended"]
        for state in states {
            await mock.sendSessionState(WatchSessionStateMessage(
                sessionId: UUID().uuidString,
                engineState: state,
                exerciseName: nil, setNumber: nil, totalSets: nil, setStatus: nil
            ))
        }
        let sent = await mock.sentStates
        XCTAssertEqual(sent.count, 4)
        XCTAssertEqual(sent.map { $0.engineState }, states)
    }

    // MARK: - Integration: SessionEngine sends watch updates on transitions

    func testSessionEngineNotifiesWatchOnStateTransition() async throws {
        let templateRepo = MockTemplateRepository()
        let sessionRepo = MockSessionRepository()
        let watchService = MockWatchSyncService()

        let templateId = UUID()
        await templateRepo.seed(template: TemplateDTO(
            id: templateId, name: "T", createdAt: Date(), exercises: []
        ))

        let engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            watchSyncService: watchService
        )

        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Give the async Task a moment
        try await Task.sleep(for: .milliseconds(100))

        let sent = await watchService.sentStates
        XCTAssertFalse(sent.isEmpty, "Watch should receive at least one state update")
        XCTAssertTrue(
            sent.contains { $0.engineState == "active" },
            "Watch should receive 'active' state. Got: \(sent.map { $0.engineState })"
        )
    }
}
