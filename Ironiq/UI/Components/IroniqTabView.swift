import SwiftUI

struct IroniqTabView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var selectedTab: AppTab = .templates
    @State private var showWorkoutDashboard = false
    @State private var showSettings = false
    @State private var showLogOnDashboardOpen = false
    @State private var showSessionSummary = false
    @State private var showActiveExercisePicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .templates:
                    HomeView()
                case .start:
                    StartView(showWorkoutDashboard: $showWorkoutDashboard, showLogOnDashboardOpen: $showLogOnDashboardOpen, showExercisePicker: $showActiveExercisePicker)
                case .history:
                    HistoryListView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
                .accessibilityIdentifier("profile_button")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showWorkoutDashboard) {
            ActiveSessionView(openLogOnAppear: $showLogOnDashboardOpen) {
                showWorkoutDashboard = false
                selectedTab = .start
                showActiveExercisePicker = true
            }
        }
        .fullScreenCover(isPresented: $showSessionSummary) {
            SessionSummaryView()
        }
        .onChange(of: sessionVM.completedSessionId) { _, sessionId in
            showSessionSummary = sessionId != nil
        }
        .onChange(of: sessionVM.isSessionActive) { _, isActive in
            if isActive {
                showWorkoutDashboard = true
                selectedTab = .start
            } else {
                showWorkoutDashboard = false
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            iconOnlyTabButton(.templates, assetName: "TemplateTabIcon", accessibilityId: "tab_templates")
            tabButton(
                .start,
                title: sessionVM.isSessionActive ? sessionVM.sessionElapsed.timerFormatted : "START",
                icon: sessionVM.isSessionActive ? "timer" : "play.fill",
                prominent: true,
                accessibilityId: "tab_start"
            )
            iconOnlyTabButton(.history, assetName: "HistoryTabIcon", accessibilityId: "tab_history")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func iconOnlyTabButton(_ tab: AppTab, assetName: String, accessibilityId: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(assetName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.78))
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(tabBackground(for: tab))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityIdentifier(accessibilityId)
    }

    private func tabButton(
        _ tab: AppTab,
        title: String,
        icon: String,
        prominent: Bool = false,
        accessibilityId: String? = nil
    ) -> some View {
        Button {
            selectedTab = tab
            if tab == .start, sessionVM.isSessionActive {
                showWorkoutDashboard = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.bold)
            }
            .font(prominent ? .headline : .subheadline)
            .foregroundStyle(tab == .start && sessionVM.isSessionActive ? .black : (selectedTab == tab ? .black : .white.opacity(0.72)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, prominent ? 15 : 13)
            .background(tabBackground(for: tab))
            .clipShape(RoundedRectangle(cornerRadius: prominent ? 18 : 14))
            .overlay(
                RoundedRectangle(cornerRadius: prominent ? 18 : 14)
                    .stroke(tab == .start && sessionVM.isSessionActive ? Color.ironiqGreen : .clear, lineWidth: 2)
            )
        }
        .accessibilityIdentifier(accessibilityId ?? "tab_\(title.lowercased())")
    }

    private func tabBackground(for tab: AppTab) -> Color {
        if tab == .start, sessionVM.isSessionActive {
            return Color.ironiqGreen
        }
        return selectedTab == tab ? Color.ironiqOrange : Color.white.opacity(0.08)
    }
}

private enum AppTab {
    case templates
    case start
    case history
}

#Preview {
    IroniqTabView()
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
        .environment(StoreKitService.shared)
}
