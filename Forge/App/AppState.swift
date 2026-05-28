import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var unitSystem: UnitSystem = .imperial
    var isProUser: Bool = false
    var hasCompletedOnboarding: Bool = CommandLine.arguments.contains("--skip-onboarding")

    // MARK: - Pro feature limits
    static let freeTemplateLimit = 7
    static let freeHistoryDays = 90
}
