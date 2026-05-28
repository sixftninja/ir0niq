import Foundation
import WatchConnectivity

// MARK: - Message types (mirror of iOS types — kept in sync)

struct WatchSessionStateMessage: Codable, Sendable {
    let sessionId: String
    let engineState: String
    let exerciseName: String?
    let setNumber: Int?
    let totalSets: Int?
    let setStatus: String?
    let targetRestDuration: TimeInterval?
}

struct WatchSetCompletionMessage: Codable, Sendable {
    let sessionId: String
    let setId: String
    let reps: Int?
    let weight: Double?
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

    func sendAction(_ action: String, sessionId: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["action": action, "sessionId": sessionId],
            replyHandler: nil
        ) { _ in }
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
