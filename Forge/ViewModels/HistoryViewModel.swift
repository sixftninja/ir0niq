import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {

    private(set) var sessions: [SessionDTO] = []
    private(set) var isLoading = false

    private let sessionRepo: any SessionRepositoryProtocol
    private let appState: AppState

    init(sessionRepo: any SessionRepositoryProtocol, appState: AppState) {
        self.sessionRepo = sessionRepo
        self.appState = appState
    }

    func loadSessions() async {
        isLoading = true
        do {
            let all = try await sessionRepo.fetchAll()
            if appState.isProUser {
                sessions = all
            } else {
                let cutoff = Date().addingTimeInterval(-TimeInterval(AppState.freeHistoryDays * 86400))
                sessions = all.filter { $0.startedAt >= cutoff }
            }
        } catch { /* non-fatal */ }
        isLoading = false
    }

    /// Dates with at least one workout (for calendar heat-map).
    var workoutDates: Set<DateComponents> {
        let cal = Calendar.current
        return Set(sessions.map { cal.dateComponents([.year, .month, .day], from: $0.startedAt) })
    }

    func sessions(on date: Date) -> [SessionDTO] {
        let cal = Calendar.current
        return sessions.filter { cal.isDate($0.startedAt, inSameDayAs: date) }
    }

    func deleteSession(_ id: UUID) async {
        do {
            try await sessionRepo.delete(sessionId: id)
            sessions.removeAll { $0.id == id }
        } catch { /* non-fatal */ }
    }
}
