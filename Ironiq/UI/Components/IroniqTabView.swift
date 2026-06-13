import SwiftUI

// MARK: - Session presentation state

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

private enum AppTab: CaseIterable {
    case analytics
    case start
    case history

    var label: String {
        switch self {
        case .analytics: return "Analytics"
        case .start:     return "Start"
        case .history:   return "History"
        }
    }
}

struct IroniqTabView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var selectedTab: AppTab = .start
    @State private var sessionPresentation: SessionPresentation = .none
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .safeAreaInset(edge: .bottom) { bottomBar }
                .overlay(alignment: .topTrailing) { profileButton }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
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
        ) { SessionSummaryView() }
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

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .analytics:
            AnalyticsView()
        case .start:
            StartTabView(
                showWorkoutDashboard: Binding(
                    get: { sessionPresentation.showsDashboard },
                    set: { if $0 { sessionPresentation = .dashboard(openLogOnAppear: false) } else { sessionPresentation = .none } }
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

    private var profileButton: some View {
        Button { showSettings = true } label: {
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

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isStart = tab == .start
        let isActive = selectedTab == tab
        let showingSession = isStart && sessionVM.isSessionActive

        return Button {
            selectedTab = tab
            if isStart, sessionVM.isSessionActive {
                sessionPresentation = .dashboard(openLogOnAppear: false)
            }
        } label: {
            VStack(spacing: 4) {
                if isStart, sessionVM.isSessionActive {
                    Text(sessionVM.sessionElapsed.timerFormatted)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.ironiqGreen)
                } else {
                    Spacer().frame(height: 14)
                }
                Text(tab.label)
                    .font(isStart ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                    .foregroundStyle(showingSession ? Color.ironiqGreen : (isActive ? Color.ironiqOrange : .white.opacity(0.6)))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.white.opacity(0.06) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("tab_\(tab.label.lowercased())")
    }
}

#Preview {
    let appState = AppState()
    IroniqTabView()
        .environment(appState)
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
            appState: appState
        ))
        .environment(SettingsViewModel())
}
