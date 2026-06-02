import SwiftUI

// MARK: - Session presentation state

// Replaces five competing booleans with a single source of truth.
// Only one session overlay can be active at a time.
private enum SessionPresentation: Equatable {
    case none
    case dashboard(openLogOnAppear: Bool)
    case summary
    case exercisePicker

    var showsDashboard: Bool {
        if case .dashboard = self { return true }
        return false
    }
    var openLogOnDashboardAppear: Bool {
        if case .dashboard(let open) = self { return open }
        return false
    }
    var showsSummary: Bool {
        if case .summary = self { return true }
        return false
    }
    var showsExercisePicker: Bool {
        if case .exercisePicker = self { return true }
        return false
    }
}

struct IroniqTabView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var selectedTab: AppTab = .templates
    @State private var sessionPresentation: SessionPresentation = .none
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .templates:
                    HomeView()
                case .start:
                    StartView(
                        showWorkoutDashboard: Binding(
                            get: { sessionPresentation.showsDashboard },
                            set: { if $0 { sessionPresentation = .dashboard(openLogOnAppear: false) } else { sessionPresentation = .none } }
                        ),
                        showLogOnDashboardOpen: Binding(
                            get: { sessionPresentation.openLogOnDashboardAppear },
                            set: { newVal in
                                if case .dashboard = sessionPresentation {
                                    sessionPresentation = .dashboard(openLogOnAppear: newVal)
                                }
                            }
                        ),
                        showExercisePicker: Binding(
                            get: { sessionPresentation.showsExercisePicker },
                            set: { if $0 { sessionPresentation = .exercisePicker } else { sessionPresentation = .none } }
                        )
                    )
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
        .fullScreenCover(
            isPresented: Binding(
                get: { sessionPresentation.showsDashboard },
                set: { if !$0 { sessionPresentation = .none } }
            )
        ) {
            ActiveSessionView(
                openLogOnAppear: Binding(
                    get: { sessionPresentation.openLogOnDashboardAppear },
                    set: { newVal in
                        if case .dashboard = sessionPresentation {
                            sessionPresentation = .dashboard(openLogOnAppear: newVal)
                        }
                    }
                )
            ) {
                selectedTab = .start
                sessionPresentation = .exercisePicker
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { sessionPresentation.showsSummary },
                set: { if !$0 { sessionPresentation = .none } }
            )
        ) {
            SessionSummaryView()
        }
        .onChange(of: sessionVM.completedSessionId) { _, sessionId in
            if sessionId != nil { sessionPresentation = .summary }
        }
        .onChange(of: sessionVM.isSessionActive) { _, isActive in
            if isActive {
                sessionPresentation = .dashboard(openLogOnAppear: false)
                selectedTab = .start
            } else if sessionPresentation.showsDashboard {
                sessionPresentation = .none
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
                sessionPresentation = .dashboard(openLogOnAppear: false)
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
