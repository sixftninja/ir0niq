import XCTest
@testable import Ironiq

/// Thread-safe counter for testing timer callbacks in Swift 6 strict concurrency.
private actor FiredTracker {
    private(set) var count = 0
    private(set) var kinds: [String] = []

    func increment() { count += 1 }
    func record(_ kind: String) { kinds.append(kind) }
}

final class TimerSystemTests: XCTestCase {

    func testTimerFires() async throws {
        let timerSystem = TimerSystem()
        let expectation = XCTestExpectation(description: "Timer fires")

        await timerSystem.schedule(.session(sessionId: UUID()), after: 0.1) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testTimerCancellationPreventsFire() async throws {
        let timerSystem = TimerSystem()
        let shouldNotFire = XCTestExpectation(description: "Cancelled timer should not fire")
        shouldNotFire.isInverted = true

        let kind = TimerKind.session(sessionId: UUID())
        await timerSystem.schedule(kind, after: 0.5) {
            shouldNotFire.fulfill()
        }
        await timerSystem.cancel(kind)

        await fulfillment(of: [shouldNotFire], timeout: 0.8)
    }

    func testIsActiveReturnsFalseBeforeScheduling() async {
        let timerSystem = TimerSystem()
        let isActive = await timerSystem.isActive(.session(sessionId: UUID()))
        XCTAssertFalse(isActive)
    }

    func testIsActiveReturnsTrueAfterScheduling() async throws {
        let timerSystem = TimerSystem()
        let kind = TimerKind.idle(sessionId: UUID())

        await timerSystem.schedule(kind, after: 60.0) {}

        let isActive = await timerSystem.isActive(kind)
        XCTAssertTrue(isActive)

        await timerSystem.cancel(kind)
    }

    func testIsActiveReturnsFalseAfterCancel() async throws {
        let timerSystem = TimerSystem()
        let kind = TimerKind.idle(sessionId: UUID())

        await timerSystem.schedule(kind, after: 60.0) {}
        await timerSystem.cancel(kind)

        let isActive = await timerSystem.isActive(kind)
        XCTAssertFalse(isActive)
    }

    func testCancelAllStopsAllTimers() async throws {
        let timerSystem = TimerSystem()
        let ids = [UUID(), UUID(), UUID()]

        for id in ids {
            await timerSystem.schedule(.session(sessionId: id), after: 60.0) {}
        }

        await timerSystem.cancelAll()

        for id in ids {
            let isActive = await timerSystem.isActive(.session(sessionId: id))
            XCTAssertFalse(isActive, "Timer for \(id) should be inactive after cancelAll")
        }
    }

    func testReschedulingOverwritesPreviousTimer() async throws {
        let timerSystem = TimerSystem()
        let kind = TimerKind.session(sessionId: UUID())
        let tracker = FiredTracker()

        // Schedule 0.5s, then immediately overwrite with 0.1s
        await timerSystem.schedule(kind, after: 0.5) { await tracker.increment() }
        await timerSystem.schedule(kind, after: 0.1) { await tracker.increment() }

        try await Task.sleep(for: .seconds(0.3))
        // Only the second scheduling's callback should have fired within 0.3s
        let count = await tracker.count
        XCTAssertEqual(count, 1, "Only the overwriting timer should have fired")
    }

    func testMultipleIndependentTimers() async throws {
        let timerSystem = TimerSystem()
        let tracker = FiredTracker()
        let sessionId1 = UUID()
        let sessionId2 = UUID()

        await timerSystem.schedule(.session(sessionId: sessionId1), after: 0.1) {
            await tracker.record("session1")
        }
        await timerSystem.schedule(.idle(sessionId: sessionId2), after: 0.2) {
            await tracker.record("idle2")
        }

        try await Task.sleep(for: .seconds(0.4))
        let kinds = await tracker.kinds
        XCTAssertTrue(kinds.contains("session1"), "session1 timer should have fired")
        XCTAssertTrue(kinds.contains("idle2"), "idle2 timer should have fired")
    }

    func testNudgeTimerFires() async throws {
        let timerSystem = TimerSystem()
        let setId = UUID()
        let expectation = XCTestExpectation(description: "Nudge fires")

        await timerSystem.schedule(.nudge(setId: setId), after: 0.1) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testSetTimerFires() async throws {
        let timerSystem = TimerSystem()
        let setId = UUID()
        let expectation = XCTestExpectation(description: "Set timer fires")

        await timerSystem.schedule(.set(setId: setId), after: 0.1) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
