import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    func resetOnboarding(appState: AppState) {
        appState.hasCompletedOnboarding = false
    }

    func toggleProSimulation(appState: AppState) {
        appState.isProUser.toggle()
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
