import SwiftUI

struct HistoryListView: View {
    @Environment(HistoryViewModel.self) private var vm
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView().tint(.forgeOrange)
                } else if vm.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Complete your first workout to see history.")
                    )
                    .background(Color.forgeDark)
                } else {
                    List {
                        sessionGroupsContent
                        proGateSection
                    }
                    .listStyle(.plain)
                    .background(Color.forgeDark)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        HistoryCalendarView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityIdentifier("calendar_button")
                }
            }
            .navigationDestination(for: SessionDTO.self) { session in
                SessionDetailView(session: session)
            }
            
        }
        .task { await vm.loadSessions() }
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
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private var proGateSection: some View {
        if !appState.isProUser {
            Section {
                ProGateView(feature: "Full history beyond 90 days") {
                    appState.isProUser = true
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var groupedSessions: [(key: String, sessions: [SessionDTO])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var grouped: [String: [SessionDTO]] = [:]
        for session in vm.sessions {
            let key = formatter.string(from: session.startedAt)
            grouped[key, default: []].append(session)
        }
        return grouped.sorted { $0.key > $1.key }.map { (key: $0.key, sessions: $0.value) }
    }
}

#Preview {
    HistoryListView()
        .environment(AppState())
        .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: AppState()))
}
