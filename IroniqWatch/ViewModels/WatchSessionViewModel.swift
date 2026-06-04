import Foundation
import SwiftUI
import WatchKit
import WidgetKit

/// Watch-side session state — mirrors the iPhone engine via WatchConnectivity.
@MainActor
@Observable
final class WatchSessionViewModel {

    // MARK: - Active session state (mirrored from phone)

    private(set) var sessionId: String? = nil
    private(set) var engineState: String = "idle"
    private(set) var exerciseName: String? = nil
    private(set) var setNumber: Int = 1
    private(set) var totalSets: Int = 1
    private(set) var setStatus: String = "pending"
    private(set) var targetReps: Int? = nil
    private(set) var targetDuration: TimeInterval? = nil
    private(set) var targetWeight: Double? = nil
    private(set) var loggingType: String = "reps"
    private(set) var unitSystem: String = "metric"

    // MARK: - End summary

    private(set) var sessionDurationSeconds: TimeInterval = 0
    private(set) var sessionVolumeKg: Double = 0

    // MARK: - Heart rate (from HKWorkoutSession)

    private(set) var heartRate: Double? = nil

    // MARK: - UI navigation

    var showInputFace = false
    var showEndConfirm = false
    var showEndSummary = false
    var showDiscarded = false
    var showReminderNudge = false

    // MARK: - Derived

    var isSessionActive: Bool {
        engineState == "active" || engineState == "paused"
    }
    var isPaused: Bool { engineState == "paused" }

    // MARK: - Private

    private let connectivity: WatchConnectivityService
    private let healthKit: WatchHealthKitService

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

    // MARK: - Apply phone state

    func apply(message: WatchSessionStateMessage) {
        let previousEngineState = engineState
        sessionId = message.sessionId.isEmpty ? nil : message.sessionId
        engineState = message.engineState

        // Clear stale end screens when a new session is in progress or ending
        if engineState == "active" || engineState == "paused" || engineState == "ending" {
            showEndSummary = false
            showDiscarded = false
        }

        // Clear stale input/nudge sheets when a fresh session begins.
        // Prevents the watch sending a phantom set completion from a previous
        // session's open input sheet, which caused the phone logCurrentSet crash.
        if engineState == "active" && previousEngineState == "idle" {
            showInputFace = false
            showReminderNudge = false
        }

        // Detect discard: ending → idle (phone or watch discarded, not saved)
        if engineState == "idle" && previousEngineState == "ending" {
            showDiscarded = true
        }
        exerciseName = message.exerciseName
        setNumber = message.setNumber ?? 1
        totalSets = message.totalSets ?? 1
        setStatus = message.setStatus ?? "pending"
        targetReps = message.targetReps
        targetDuration = message.targetDuration
        targetWeight = message.targetWeight
        loggingType = message.loggingType ?? "reps"
        if let us = message.unitSystem { unitSystem = us }

        if message.reminderFired == true {
            WKInterfaceDevice.current().play(.notification)
            showReminderNudge = true
        }

        if let dur = message.sessionDurationSeconds { sessionDurationSeconds = dur }
        if let vol = message.sessionVolumeKg { sessionVolumeKg = vol }
        // Only show the end screen if we haven't already dismissed it locally
        // (previousEngineState == "idle" means user already tapped Done)
        if engineState == "ended" && previousEngineState != "idle" && sessionDurationSeconds > 0 {
            showEndSummary = true
        }

        // Keep-alive: start extended runtime session so app stays in foreground
        // and wrist-raise brings it back. End HK workout when no longer active.
        let keepAlive = isSessionActive || engineState == "ending" || engineState == "ended"
        if keepAlive {
            healthKit.startExtendedSession()
            if isSessionActive && !healthKit.isSessionActive {
                Task { try? await healthKit.startSession() }
            } else if !isSessionActive && healthKit.isSessionActive {
                Task { try? await healthKit.endSession() }
            }
        } else {
            // Transitioned to idle — stop everything
            healthKit.stopExtendedSession()
            if healthKit.isSessionActive {
                Task { try? await healthKit.endSession() }
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "IroniqComplication")
    }

    // MARK: - User actions → sent to iPhone

    func sendFinishSet() {
        showInputFace = true
        WKInterfaceDevice.current().play(.click)
    }

    func logCurrentSet(reps: Int, durationSeconds: TimeInterval, weight: Double) {
        guard let sid = sessionId else { return }
        let repsVal: Int? = loggingType == "reps" ? reps : nil
        let durVal: TimeInterval? = loggingType == "duration" && durationSeconds > 0 ? durationSeconds : nil
        connectivity.sendSetCompletion(WatchSetCompletionMessage(
            sessionId: sid,
            setId: UUID().uuidString,
            reps: repsVal,
            durationSeconds: durVal,
            weight: weight > 0 ? weight : nil
        ))
        WKInterfaceDevice.current().play(.directionUp)  // haptic only, no chime
        showInputFace = false
    }

    func sendSkipSet() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "skipSet", sessionId: sid, templateId: nil))
    }

    func sendPause() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "pause", sessionId: sid, templateId: nil))
        WKInterfaceDevice.current().play(.click)
    }

    func sendResume() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "resume", sessionId: sid, templateId: nil))
        WKInterfaceDevice.current().play(.success)
    }

    func requestEnd() {
        guard let sid = sessionId else { return }
        showEndConfirm = false
        connectivity.sendAction(WatchActionMessage(action: "end", sessionId: sid, templateId: nil))
        WKInterfaceDevice.current().play(.click)
    }

    /// Save workout — sent from WatchEndChoiceView when engine is in "ending" state
    func saveFromWatch() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "confirmEnd", sessionId: sid, templateId: nil))
        WKInterfaceDevice.current().play(.success)
    }

    func sendMediaAction(_ action: String) {
        connectivity.sendAction(WatchActionMessage(action: action, sessionId: nil, templateId: nil))
    }

    /// Discard workout — sent from WatchEndChoiceView when engine is in "ending" state
    func discardFromWatch() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "discard", sessionId: sid, templateId: nil))
    }

    /// Dismisses the unified "Workout Ended" screen — returns watch to idle.
    func dismissWorkoutEnded() {
        showEndSummary = false
        showDiscarded = false
        engineState = "idle"
        healthKit.stopExtendedSession()
        Task { try? await healthKit.endSession() }
    }

    // Keep legacy dismissals for any remaining callers (safety)
    func dismissEndSummary() { dismissWorkoutEnded() }
    func dismissDiscarded() { dismissWorkoutEnded() }

    // MARK: - Display helpers

    var targetDisplayText: String {
        if loggingType == "duration", let d = targetDuration {
            let secs = Int(d)
            return secs >= 60 ? "\(secs / 60)m \(secs % 60)s" : "\(secs) sec"
        }
        if let r = targetReps { return "\(r) reps" }
        return "—"
    }

    func weightText(kg: Double) -> String {
        if kg <= 0 { return "Bodyweight" }
        if unitSystem == "imperial" {
            return String(format: "%.0f lb", kg * 2.20462)
        }
        return String(format: "%.1f kg", kg)
    }

    var targetWeightText: String {
        weightText(kg: targetWeight ?? 0)
    }
}
