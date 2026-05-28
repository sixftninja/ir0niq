import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            ForgeTabView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
        .environment(HistoryViewModel(
            sessionRepo: PreviewRepositories.session,
            appState: AppState()
        ))
        .environment(SettingsViewModel())
}
