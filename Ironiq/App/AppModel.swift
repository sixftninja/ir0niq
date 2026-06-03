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
        SessionIntentBridge.shared.setEngine(engine)

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

        Task { await StoreKitService.shared.initialize(appState: appState) }
    }

    // MARK: - Watch action handling

    // Called from IroniqApp once the engine and templateVM are ready.
    func startWatchSync() async {
        await WatchSyncService.shared.activate()

        // Handle set completions from watch (log a set)
        await WatchSyncService.shared.onSetCompletion { [weak self] msg in
            guard let self else { return }
            Task { @MainActor in
                await self.sessionVM.logCurrentSet(
                    reps: msg.reps,
                    durationSeconds: msg.durationSeconds,
                    weight: msg.weight
                )
                await self.sessionVM.advanceToNext()
            }
        }

        // Handle action messages from watch
        await WatchSyncService.shared.onWatchAction { [weak self] msg in
            guard let self else { return }
            Task { @MainActor in await self.handleWatchAction(msg) }
        }

        // Send current template list to watch
        await sendTemplateListToWatch()
    }

    private func handleWatchAction(_ msg: WatchActionMessage) async {
        switch msg.action {
        case "startTemplate":
            guard let idStr = msg.templateId, let id = UUID(uuidString: idStr) else { return }
            let started = await sessionVM.startTemplateSession(id)
            if started { await sendTemplateListToWatch() }  // clears list on watch when active
        case "skipSet":
            await sessionVM.skipCurrentSet()
        case "pause":
            await sessionVM.pauseSession()
        case "resume":
            await sessionVM.resumeSession()
        case "end":
            _ = await sessionVM.endSession()
        case "confirmEnd":
            await sessionVM.confirmEnd()
        case "save":
            // Session already saved via confirmEnd; just send updated idle state with templates
            await sendTemplateListToWatch()
        case "discard":
            await sendTemplateListToWatch()
        default:
            break
        }
    }

    // Sends current template list to watch (called on idle state and after save/discard)
    func sendTemplateListToWatch() async {
        guard WatchSyncService.shared.isReachable else { return }
        let templates = templateVM.templates.map {
            WatchTemplateInfo(id: $0.id.uuidString, name: $0.name, exerciseCount: $0.exercises.count)
        }
        let msg = WatchSessionStateMessage(
            sessionId: "",
            engineState: "idle",
            exerciseName: nil, setNumber: nil, totalSets: nil, setStatus: nil,
            targetReps: nil, targetDuration: nil, targetWeight: nil,
            loggingType: nil,
            unitSystem: appState.unitSystem == .imperial ? "imperial" : "metric",
            templates: templates,
            reminderFired: nil, sessionDurationSeconds: nil, sessionVolumeKg: nil
        )
        await WatchSyncService.shared.sendSessionState(msg)
    }

    // MARK: - Cloud sync

    func performStartupSync() async {
        guard let provider = appState.syncProvider else { return }

        let restorer = CloudRestoreService(templateRepo: templateRepo, sessionRepo: sessionRepo)
        let result = await restorer.restoreIfNeeded(provider: provider)

        if result.templatesRestored > 0 || result.sessionsRestored > 0 {
            await templateVM.loadAll()
            await historyVM.loadSessions()
        }

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
                        PendingExportQueue.shared.remove(id: item.id)
                    }
                case .session:
                    PendingExportQueue.shared.incrementRetry(id: item.id)
                }
            } catch {
                PendingExportQueue.shared.incrementRetry(id: item.id)
            }
        }
    }
}
