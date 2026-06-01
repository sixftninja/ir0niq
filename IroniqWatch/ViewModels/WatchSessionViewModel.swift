import Foundation
import SwiftUI
import WatchKit

/// Watch-side session state — mirrors the iPhone engine via WatchConnectivity.
@MainActor
@Observable
final class WatchSessionViewModel {

    // MARK: - Mirrored state (from iPhone)

    private(set) var sessionId: String? = nil
    private(set) var engineState: String = "idle"
    private(set) var exerciseName: String? = nil
    private(set) var setNumber: Int = 1
    private(set) var totalSets: Int = 1
    private(set) var setStatus: String = "pending"
    private(set) var targetRestDuration: TimeInterval? = nil

    // MARK: - Live timers (updated every 500 ms)

    private(set) var setElapsed: TimeInterval = 0
    private(set) var restElapsed: TimeInterval = 0
    private(set) var restRemaining: TimeInterval = 0
    private(set) var hasRestTarget = false

    // MARK: - Heart rate (from HKWorkoutSession)

    private(set) var heartRate: Double? = nil

    // MARK: - UI navigation

    var showInputFace = false
    var showEndConfirm = false
    var showCelebration = false

    // MARK: - Derived

    var isSessionActive: Bool {
        engineState == "active" || engineState == "paused"
    }
    var isPaused: Bool { engineState == "paused" }

    // MARK: - Private

    private let connectivity: WatchConnectivityService
    private let healthKit: WatchHealthKitService
    private var tickerTask: Task<Void, Never>?
    var statusChangedAt = Date()       // internal for @testable
    private var lastHapticSecond = -1

    init(
        connectivity: WatchConnectivityService = .shared,
        healthKit: WatchHealthKitService = .shared
    ) {
        self.connectivity = connectivity
        self.healthKit = healthKit
        setupHandlers()
        Task { connectivity.activate() }
        Task { try? await healthKit.requestAuthorization() }
    }

    // MARK: - Setup

    private func setupHandlers() {
        connectivity.onSessionStateReceived = { [weak self] msg in
            Task { @MainActor in self?.apply(message: msg) }
        }
        healthKit.onHeartRateUpdate = { [weak self] bpm in
            Task { @MainActor in self?.heartRate = bpm }
        }
    }

    // MARK: - Apply iPhone state

    func apply(message: WatchSessionStateMessage) {  // internal for @testable
        sessionId = message.sessionId
        let prevStatus = setStatus
        engineState = message.engineState
        exerciseName = message.exerciseName
        setNumber = message.setNumber ?? 1
        totalSets = message.totalSets ?? 1
        let newStatus = message.setStatus ?? "pending"
        targetRestDuration = message.targetRestDuration
        hasRestTarget = message.targetRestDuration != nil

        if newStatus != prevStatus {
            setStatus = newStatus
            statusChangedAt = Date()
            lastHapticSecond = -1
            showCelebration = false
        }

        // Manage HK session lifecycle
        if isSessionActive && !healthKit.isSessionActive {
            Task { try? await healthKit.startSession() }
        } else if !isSessionActive && healthKit.isSessionActive {
            Task { try? await healthKit.endSession() }
        }

        isSessionActive ? startTicker() : stopTicker()
    }

    // MARK: - Timer tick

    private func startTicker() {
        guard tickerTask == nil || tickerTask!.isCancelled else { return }
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.tick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(statusChangedAt)
        switch setStatus {
        case "inProgress":
            setElapsed = elapsed
        case "resting":
            restElapsed = elapsed
            if let target = targetRestDuration {
                let remaining = max(0, target - elapsed)
                restRemaining = remaining
                triggerHapticCountdown(remaining: remaining)
            }
        default:
            break
        }
    }

    // MARK: - Haptic countdown (edge case 1: 5-second countdown before rest ends)

    func triggerHapticCountdown(remaining: TimeInterval) {
        guard hasRestTarget else { return }
        let secondsLeft = Int(ceil(remaining))

        if remaining <= 0 && lastHapticSecond != 0 {
            // Rest ended — celebration haptic + green ring
            WKInterfaceDevice.current().play(.success)
            lastHapticSecond = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCelebration = true
            }
            // Auto-dismiss celebration after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { self.showCelebration = false }
            }
            return
        }

        guard secondsLeft > 0 && secondsLeft <= 5 && secondsLeft != lastHapticSecond else { return }
        lastHapticSecond = secondsLeft
        WKInterfaceDevice.current().play(.click)  // countdown tick
    }

    // MARK: - User actions → sent to iPhone

    func sendBeginSet() {
        guard let sid = sessionId else { return }
        connectivity.sendAction("beginSet", sessionId: sid)
    }

    func sendRest() {
        guard let sid = sessionId else { return }
        connectivity.sendAction("tapRest", sessionId: sid)
    }

    func logCurrentSet(reps: Int, weight: Double) {
        guard let sid = sessionId else { return }
        connectivity.sendSetCompletion(WatchSetCompletionMessage(
            sessionId: sid,
            setId: UUID().uuidString,
            reps: reps > 0 ? reps : nil,
            weight: weight > 0 ? weight : nil
        ))
        showInputFace = false
    }

    func sendPause() {
        guard let sid = sessionId else { return }
        connectivity.sendAction("pause", sessionId: sid)
    }

    func sendResume() {
        guard let sid = sessionId else { return }
        connectivity.sendAction("resume", sessionId: sid)
    }

    func confirmEndSession() {
        guard let sid = sessionId else { return }
        connectivity.sendAction("end", sessionId: sid)
        showEndConfirm = false
    }
}
