import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    var unitSystem: UnitSystem = .imperial
    var isProUser: Bool = false
    var hasCompletedOnboarding: Bool = CommandLine.arguments.contains("--skip-onboarding")
    var useDarkMode: Bool = true   // default: dark (gym context)

    // MARK: - Pro feature limits (nonisolated so they can be read from any context)
    nonisolated static let freeTemplateLimit = 7
    nonisolated static let freeHistoryDays = 90
}
