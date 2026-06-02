import Foundation

// Provides AppIntents with safe, structured access to the active SessionEngine.
//
// Replaces the nonisolated(unsafe) static var on SessionEngine, which bypassed
// actor isolation and could not be tested in isolation. The bridge is set once
// at app startup (in AppModel.init) and read by each AppIntent before performing
// its action.

@MainActor
final class SessionIntentBridge {
    static let shared = SessionIntentBridge()
    private var _engine: SessionEngine?

    private init() {}

    func setEngine(_ engine: SessionEngine) {
        _engine = engine
    }

    /// Returns the active engine, or nil if the app has not yet initialized.
    func engine() -> SessionEngine? {
        _engine
    }
}
