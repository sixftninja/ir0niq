import XCTest
@testable import ForgeWatch

final class WatchSessionViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeMessage(
        sessionId: String = "test-session",
        engineState: String = "active",
        exerciseName: String? = "Deadlift",
        setNumber: Int = 1,
        totalSets: Int = 3,
        setStatus: String = "pending",
        targetRestDuration: TimeInterval? = nil
    ) -> WatchSessionStateMessage {
        WatchSessionStateMessage(
            sessionId: sessionId,
            engineState: engineState,
            exerciseName: exerciseName,
            setNumber: setNumber,
            totalSets: totalSets,
            setStatus: setStatus,
            targetRestDuration: targetRestDuration
        )
    }

    // MARK: - State transitions

    @MainActor
    func testInitialStateIsIdle() {
        let vm = WatchSessionViewModel()
        XCTAssertEqual(vm.engineState, "idle")
        XCTAssertFalse(vm.isSessionActive)
    }

    @MainActor
    func testActiveMessageMakesSessionActive() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(engineState: "active"))
        XCTAssertTrue(vm.isSessionActive)
        XCTAssertEqual(vm.engineState, "active")
    }

    @MainActor
    func testExerciseNamePropagated() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(engineState: "active", exerciseName: "Deadlift"))
        XCTAssertEqual(vm.exerciseName, "Deadlift")
    }

    @MainActor
    func testSetNumberAndTotalPropagated() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setNumber: 2, totalSets: 4))
        XCTAssertEqual(vm.setNumber, 2)
        XCTAssertEqual(vm.totalSets, 4)
    }

    @MainActor
    func testPausedStateDetected() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(engineState: "paused"))
        XCTAssertTrue(vm.isPaused)
        XCTAssertTrue(vm.isSessionActive)
    }

    @MainActor
    func testEndedStateDeactivatesSession() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(engineState: "active"))
        vm.apply(message: makeMessage(engineState: "ended"))
        XCTAssertFalse(vm.isSessionActive)
    }

    @MainActor
    func testRestTargetStoredWhenResting() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "resting", targetRestDuration: 90))
        XCTAssertTrue(vm.hasRestTarget)
        XCTAssertEqual(vm.targetRestDuration, 90)
    }

    @MainActor
    func testNoRestTargetWhenNil() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "resting", targetRestDuration: nil))
        XCTAssertFalse(vm.hasRestTarget)
    }

    @MainActor
    func testStatusChangeResetsTimer() throws {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "pending"))
        let t1 = vm.statusChangedAt

        // Give a tiny moment to ensure the clock advances
        Thread.sleep(forTimeInterval: 0.01)
        vm.apply(message: makeMessage(setStatus: "inProgress"))
        let t2 = vm.statusChangedAt

        XCTAssertGreaterThan(t2.timeIntervalSince(t1), 0)
    }

    @MainActor
    func testSameStatusDoesNotResetTimer() throws {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "inProgress"))
        let t1 = vm.statusChangedAt

        Thread.sleep(forTimeInterval: 0.01)
        vm.apply(message: makeMessage(setStatus: "inProgress"))  // same status
        let t2 = vm.statusChangedAt

        XCTAssertEqual(t1, t2, "Same status should NOT reset the timer reference")
    }

    // MARK: - Haptic countdown logic (tests the decision logic, not the hardware API)

    @MainActor
    func testHapticCountdown_CelebrationShownAtZero() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "resting", targetRestDuration: 60))
        // Simulate rest ending
        vm.triggerHapticCountdown(remaining: 0)
        XCTAssertTrue(vm.showCelebration, "showCelebration should be set when rest ends on time")
    }

    @MainActor
    func testHapticCountdown_NoCelebrationAboveZero() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "resting", targetRestDuration: 60))
        vm.triggerHapticCountdown(remaining: 3)
        XCTAssertFalse(vm.showCelebration, "showCelebration should not appear before rest ends")
    }

    @MainActor
    func testHapticCountdown_NoTargetNoHaptic() {
        let vm = WatchSessionViewModel()
        vm.apply(message: makeMessage(setStatus: "resting", targetRestDuration: nil))
        // With no target, countdown should do nothing harmful
        vm.triggerHapticCountdown(remaining: 0)
        XCTAssertFalse(vm.showCelebration, "No celebration without a rest target")
    }

    // MARK: - User actions (verify they don't crash)

    @MainActor
    func testSendBeginSetWithNoSession() {
        let vm = WatchSessionViewModel()
        XCTAssertNoThrow(vm.sendBeginSet())
    }

    @MainActor
    func testLogSetWithNoSession() {
        let vm = WatchSessionViewModel()
        XCTAssertNoThrow(vm.logCurrentSet(reps: 5, weight: 100))
    }

    @MainActor
    func testLogSetDismissesInputFace() {
        let vm = WatchSessionViewModel()
        vm.showInputFace = true
        vm.apply(message: makeMessage())  // set a session ID
        vm.logCurrentSet(reps: 5, weight: 100)
        XCTAssertFalse(vm.showInputFace, "Input face should close after logging")
    }
}
