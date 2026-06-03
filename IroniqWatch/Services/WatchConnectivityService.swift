import Foundation
import WatchConnectivity

// MARK: - Message types (mirror of iOS types — kept in sync)

struct WatchTemplateInfo: Codable, Sendable {
    let id: String
    let name: String
    let exerciseCount: Int
}

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
    let loggingType: String?
    let unitSystem: String?
    let templates: [WatchTemplateInfo]?
    let reminderFired: Bool?
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

struct WatchActionMessage: Codable, Sendable {
    let action: String
    let sessionId: String?
    let templateId: String?
}

// MARK: - Service

@MainActor
final class WatchConnectivityService: NSObject, @unchecked Sendable {
    static let shared = WatchConnectivityService()

    var onSessionStateReceived: ((WatchSessionStateMessage) -> Void)?
    private(set) var isReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSetCompletion(_ message: WatchSetCompletionMessage) {
        guard WCSession.default.isReachable,
              let data = try? JSONEncoder().encode(message) else { return }
        WCSession.default.sendMessageData(data, replyHandler: nil) { _ in }
    }

    func sendAction(_ message: WatchActionMessage) {
        guard WCSession.default.isReachable,
              let data = try? JSONEncoder().encode(message) else { return }
        WCSession.default.sendMessageData(data, replyHandler: nil) { _ in }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = activationState == .activated && session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard let msg = try? JSONDecoder().decode(WatchSessionStateMessage.self, from: messageData) else { return }
        Task { @MainActor in self.onSessionStateReceived?(msg) }
    }
}
