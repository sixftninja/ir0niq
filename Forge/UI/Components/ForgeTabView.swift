import SwiftUI

struct ForgeTabView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
                .accessibilityIdentifier("tab_home")

            TemplateListView()
                .tabItem { Label("Templates", systemImage: "list.bullet.rectangle") }
                .tag(1)
                .accessibilityIdentifier("tab_templates")

            HistoryListView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(2)
                .accessibilityIdentifier("tab_history")

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
                .accessibilityIdentifier("tab_settings")
        }
        .tint(.forgeOrange)
        // isSessionActive is a stored @Observable property — changes are tracked directly
        .fullScreenCover(isPresented: Binding(
            get: { sessionVM.isSessionActive },
            set: { if !$0 { Task { await sessionVM.reset() } } }
        )) {
            ActiveSessionView()
        }
    }
}

#Preview {
    ForgeTabView()
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
