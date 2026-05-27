import Foundation
import WatchConnectivity

// MARK: - Message types

struct WatchSessionStateMessage: Codable, Sendable {
    let sessionId: String
    let engineState: String
    let exerciseName: String?
    let setNumber: Int?
    let totalSets: Int?
    let setStatus: String?
}

struct WatchSetCompletionMessage: Codable, Sendable {
    let sessionId: String
    let setId: String
    let reps: Int?
    let weight: Double?
}

// MARK: - Received message handler

typealias WatchMessageHandler = @Sendable (WatchSetCompletionMessage) -> Void

// MARK: - Protocol

protocol WatchSyncServiceProtocol: Sendable {
    func activate() async
    var isReachable: Bool { get async }
    func sendSessionState(_ message: WatchSessionStateMessage) async
    func onSetCompletion(_ handler: @escaping WatchMessageHandler) async
}

// MARK: - Production implementation

@MainActor
final class WatchSyncService: NSObject, WatchSyncServiceProtocol, @unchecked Sendable {
    private(set) var isReachable: Bool = false
    private var completionHandler: WatchMessageHandler?
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
        guard isReachable, WCSession.default.isReachable else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        WCSession.default.sendMessageData(data, replyHandler: nil) { _ in }
    }

    func onSetCompletion(_ handler: @escaping WatchMessageHandler) async {
        completionHandler = handler
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Extract Sendable values before crossing actor boundary
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
            self.isReachable = reachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data
    ) {
        guard let message = try? JSONDecoder().decode(WatchSetCompletionMessage.self, from: messageData) else { return }
        Task { @MainActor in
            self.completionHandler?(message)
        }
    }

    // Required on iOS — watchOS counterpart not needed here
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
