import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    func resetOnboarding(appState: AppState) {
        appState.hasCompletedOnboarding = false
    }

var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
