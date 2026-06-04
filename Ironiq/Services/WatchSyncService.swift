import Foundation
import WatchConnectivity

// MARK: - Shared types (phone ↔ watch)

struct WatchSessionStateMessage: Codable, Sendable {
    let sessionId: String
    let engineState: String
    let exerciseName: String?
    let setNumber: Int?
    let totalSets: Int?
    let setStatus: String?
    let targetReps: Int?
    let targetDuration: TimeInterval?
    let targetWeight: Double?
    let loggingType: String?              // "reps" | "duration"
    let unitSystem: String?               // "imperial" | "metric"
    var reminderFired: Bool?
    let sessionDurationSeconds: TimeInterval?
    let sessionVolumeKg: Double?
}

struct WatchSetCompletionMessage: Codable, Sendable {
    let sessionId: String
    let setId: String
    let reps: Int?
    let durationSeconds: TimeInterval?
    let weight: Double?
}

// MARK: - Watch action message (watch → phone)

struct WatchActionMessage: Codable, Sendable {
    let action: String       // "skipSet" | "startTemplate" | "save" | "discard" | "pause" | "resume" | "end" | etc.
    let sessionId: String?
    let templateId: String?
}

// MARK: - Handlers

typealias WatchMessageHandler = @Sendable (WatchSetCompletionMessage) -> Void
typealias WatchActionHandler = @Sendable (WatchActionMessage) -> Void

// MARK: - Protocol

protocol WatchSyncServiceProtocol: Sendable {
    func activate() async
    var isReachable: Bool { get async }
    func sendSessionState(_ message: WatchSessionStateMessage) async
    func onSetCompletion(_ handler: @escaping WatchMessageHandler) async
    func onWatchAction(_ handler: @escaping WatchActionHandler) async
}

// MARK: - Production implementation

@MainActor
final class WatchSyncService: NSObject, WatchSyncServiceProtocol, @unchecked Sendable {
    private(set) var isReachable: Bool = false
    private var completionHandler: WatchMessageHandler?
    private var actionHandler: WatchActionHandler?
    var onBecameReachable: (() -> Void)?
    private var activationContinuation: CheckedContinuation<Void, Never>?

    static let shared = WatchSyncService()

    private override init() { super.init() }

    func activate() async {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        await withCheckedContinuation { continuation in
            activationContinuation = continuation
            WCSession.default.activate()
        }
    }

    func sendSessionState(_ message: WatchSessionStateMessage) async {
        guard let data = try? JSONEncoder().encode(message) else { return }
        // Always persist context so watch recovers state when it opens (even if not reachable)
        try? WCSession.default.updateApplicationContext(["state": data.base64EncodedString()])
        // Also push real-time update when both devices are reachable
        if isReachable && WCSession.default.isReachable {
            WCSession.default.sendMessageData(data, replyHandler: nil) { _ in }
        }
    }

    func onSetCompletion(_ handler: @escaping WatchMessageHandler) async {
        completionHandler = handler
    }

    func onWatchAction(_ handler: @escaping WatchActionHandler) async {
        actionHandler = handler
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = (activationState == .activated && session.isReachable)
        Task { @MainActor in
            self.isReachable = reachable
            self.activationContinuation?.resume()
            self.activationContinuation = nil
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            let wasReachable = self.isReachable
            self.isReachable = reachable
            if reachable && !wasReachable {
                self.onBecameReachable?()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Try set completion first, then action message
        if let msg = try? JSONDecoder().decode(WatchSetCompletionMessage.self, from: messageData) {
            Task { @MainActor in self.completionHandler?(msg) }
            return
        }
        if let msg = try? JSONDecoder().decode(WatchActionMessage.self, from: messageData) {
            Task { @MainActor in self.actionHandler?(msg) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
