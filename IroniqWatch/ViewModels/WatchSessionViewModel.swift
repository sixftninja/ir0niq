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
        sessionId = message.sessionId.isEmpty ? nil : message.sessionId
        engineState = message.engineState
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
        if engineState == "ended" && sessionDurationSeconds > 0 {
            showEndSummary = true
        }

        if isSessionActive && !healthKit.isSessionActive {
            Task { try? await healthKit.startSession() }
        } else if !isSessionActive && healthKit.isSessionActive {
            Task { try? await healthKit.endSession() }
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
        WKInterfaceDevice.current().play(.success)
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
        WKInterfaceDevice.current().play(.success)
    }

    func sendSave() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "save", sessionId: sid, templateId: nil))
        WKInterfaceDevice.current().play(.success)
        showEndSummary = false
        engineState = "idle"
    }

    func sendDiscard() {
        guard let sid = sessionId else { return }
        connectivity.sendAction(WatchActionMessage(action: "discard", sessionId: sid, templateId: nil))
        showEndSummary = false
        engineState = "idle"
    }

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
