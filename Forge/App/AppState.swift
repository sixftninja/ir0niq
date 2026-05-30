import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    var unitSystem: UnitSystem = .imperial
    var isProUser: Bool = false
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        || CommandLine.arguments.contains("--skip-onboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var useDarkMode: Bool = true   // default: dark (gym context)

    // MARK: - Pro feature limits (nonisolated so they can be read from any context)
    nonisolated static let freeTemplateLimit = 7
    nonisolated static let freeHistoryDays = 90
}
