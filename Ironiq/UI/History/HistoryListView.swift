import SwiftUI

struct HistoryListView: View {
    @Environment(HistoryViewModel.self) private var vm
    @State private var selectedView: HistoryViewMode = .list

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                historyModePicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Group {
                    if vm.isLoading {
                        ProgressView().tint(.ironiqOrange)
                    } else if selectedView == .calendar {
                        HistoryCalendarView()
                    } else if vm.sessions.isEmpty {
                        ContentUnavailableView(
                            "No Sessions",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Complete your first workout to see history.")
                        )
                    } else {
                        List {
                            sessionGroupsContent
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.ironiqDark)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SessionDTO.self) { session in
                SessionDetailView(session: session)
            }
            }
        .task { await vm.loadSessions() }
    }

    private var historyModePicker: some View {
        Picker("History view", selection: $selectedView) {
            Label("List", systemImage: "list.bullet").tag(HistoryViewMode.list)
            Label("Calendar", systemImage: "calendar").tag(HistoryViewMode.calendar)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("history_view_picker")
    }

    @ViewBuilder
    private var sessionGroupsContent: some View {
        ForEach(groupedSessions, id: \.key) { group in
            Section(group.key) {
                ForEach(group.sessions) { session in
                    NavigationLink(value: session) {
                        SessionRowView(session: session)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(Color.white.opacity(0.12))
                }
            }
        }
    }


    private var groupedSessions: [(key: String, sessions: [SessionDTO])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let cal = Calendar.current
        var grouped: [Date: [SessionDTO]] = [:]
        for session in vm.sessions {
            let comps = cal.dateComponents([.year, .month], from: session.startedAt)
            let monthStart = cal.date(from: comps) ?? session.startedAt
            grouped[monthStart, default: []].append(session)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: formatter.string(from: $0.key), sessions: $0.value) }
    }
}

private enum HistoryViewMode: String, CaseIterable {
    case list
    case calendar
}

#Preview {
    HistoryListView()
        .environment(AppState())
        .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: AppState()))
}
