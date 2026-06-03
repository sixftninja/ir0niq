import Foundation
import SwiftData
import Observation

/// Top-level dependency container. Created once at app startup and injected
/// via @Environment throughout the view hierarchy.
@MainActor
@Observable
final class AppModel {
    let appState: AppState
    let sessionVM: SessionViewModel
    let templateVM: TemplateViewModel
    let historyVM: HistoryViewModel
    let settingsVM: SettingsViewModel
    let engine: SessionEngine
    let storeKit: StoreKitService

    private let templateRepo: TemplateRepository
    private let sessionRepo: SessionRepository

    init(modelContainer: ModelContainer) {
        let appState = AppState()
        self.appState = appState

        let engine = SessionEngine.make(modelContainer: modelContainer)
        self.engine = engine
        SessionIntentBridge.shared.setEngine(engine)  // makes engine available to AppIntents

        let templateRepo = TemplateRepository(modelContainer: modelContainer)
        let exerciseRepo = ExerciseRepository(modelContainer: modelContainer)
        let sessionRepo = SessionRepository(modelContainer: modelContainer)

        self.templateRepo = templateRepo
        self.sessionRepo = sessionRepo

        self.sessionVM = SessionViewModel(engine: engine)
        self.templateVM = TemplateViewModel(templateRepo: templateRepo, exerciseRepo: exerciseRepo)
        self.historyVM = HistoryViewModel(sessionRepo: sessionRepo, appState: appState)
        self.settingsVM = SettingsViewModel()
        self.storeKit = StoreKitService.shared

        // Initialize StoreKit (non-blocking — happens in background)
        Task { await StoreKitService.shared.initialize(appState: appState) }
    }

    // Called at startup and after sign-in. Restores from cloud and retries any
    // previously failed exports (e.g. templates that didn't make it to iCloud).
    func performStartupSync() async {
        guard let provider = appState.syncProvider else { return }

        // Restore cloud content first
        let restorer = CloudRestoreService(templateRepo: templateRepo, sessionRepo: sessionRepo)
        let result = await restorer.restoreIfNeeded(provider: provider)

        if result.templatesRestored > 0 || result.sessionsRestored > 0 {
            await templateVM.loadAll()
            await historyVM.loadSessions()
        }

        // Retry any pending exports (items that failed to reach cloud on a previous run)
        await retryPendingExports()

        if PendingExportQueue.shared.isEmpty {
            appState.markSyncHealthy()
        } else {
            let count = PendingExportQueue.shared.allItems().count
            appState.markSyncFailing("\(count) item(s) waiting to sync")
        }
    }

    private func retryPendingExports() async {
        let items = PendingExportQueue.shared.allItems()
        guard !items.isEmpty else { return }

        for item in items {
            do {
                switch item.type {
                case .template:
                    if let dto = try await templateRepo.fetchById(item.id) {
                        let model = TemplateExportModel(from: dto)
                        _ = try await CloudStorageRouter.shared.exportTemplate(model)
                        PendingExportQueue.shared.remove(id: item.id)
                    } else {
                        // Template was deleted — remove from queue
                        PendingExportQueue.shared.remove(id: item.id)
                    }
                case .session:
                    // Session export requires the full DTO; skip silently for now
                    PendingExportQueue.shared.incrementRetry(id: item.id)
                }
            } catch {
                PendingExportQueue.shared.incrementRetry(id: item.id)
            }
        }
    }
}
