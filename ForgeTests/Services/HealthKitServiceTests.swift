import XCTest
@testable import Forge

final class HealthKitServiceTests: XCTestCase {

    var mock: MockHealthKitService!

    override func setUp() async throws {
        mock = MockHealthKitService()
    }

    func testIsAvailableReturnsConfiguredValue() {
        XCTAssertTrue(mock.isAvailable())
    }

    func testIsAvailableReturnsFalseWhenConfigured() {
        mock.set(availableResult: false)
        XCTAssertFalse(mock.isAvailable())
    }

    func testRequestAuthorizationSucceeds() async throws {
        try await mock.requestAuthorization()
        // No error means success
    }

    func testRequestAuthorizationPropagatesError() async {
        let expectedError = HealthKitError.authorizationDenied
        mock.set(authorizationError: expectedError)
        do {
            try await mock.requestAuthorization()
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testStartWorkoutRecorded() async throws {
        let sessionId = UUID()
        let startDate = Date()
        try await mock.startWorkout(sessionId: sessionId, startDate: startDate)
        XCTAssertEqual(mock.startedWorkouts.count, 1)
        XCTAssertEqual(mock.startedWorkouts.first?.sessionId, sessionId)
    }

    func testEndWorkoutRecordedAndReturnsId() async throws {
        let sessionId = UUID()
        let expectedId = UUID()
        mock.set(workoutIdToReturn: expectedId)
        try await mock.startWorkout(sessionId: sessionId, startDate: Date())
        let returnedId = try await mock.endWorkout(sessionId: sessionId, endDate: Date())
        XCTAssertEqual(returnedId, expectedId)
        XCTAssertEqual(mock.endedWorkouts.count, 1)
    }

    func testAddEnergyBurned() async throws {
        try await mock.addActiveEnergyBurned(150, at: Date())
        XCTAssertEqual(mock.energySamples.count, 1)
        XCTAssertEqual(mock.energySamples.first?.kcal, 150)
    }

    // MARK: - Integration: SessionEngine calls HealthKit service

    func testSessionEngineCallsHealthKitOnStart() async throws {
        let templateRepo = MockTemplateRepository()
        let sessionRepo = MockSessionRepository()
        let hkService = MockHealthKitService()

        let templateId = UUID()
        await templateRepo.seed(template: TemplateDTO(
            id: templateId, name: "T", createdAt: Date(), exercises: []
        ))

        let engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            healthKitService: hkService
        )

        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()

        // Give async task a moment
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(hkService.startedWorkouts.count, 1,
                       "HealthKit startWorkout should be called on session start")
    }

    func testSessionEngineCallsHealthKitOnEnd() async throws {
        let templateRepo = MockTemplateRepository()
        let sessionRepo = MockSessionRepository()
        let hkService = MockHealthKitService()

        let templateId = UUID()
        await templateRepo.seed(template: TemplateDTO(
            id: templateId, name: "T", createdAt: Date(), exercises: []
        ))

        let engine = SessionEngine(
            templateRepository: templateRepo,
            sessionRepository: sessionRepo,
            healthKitService: hkService
        )

        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()
        _ = try await engine.endSession()
        try await engine.confirmEnd()

        XCTAssertEqual(hkService.endedWorkouts.count, 1,
                       "HealthKit endWorkout should be called on session confirm-end")
    }
}
