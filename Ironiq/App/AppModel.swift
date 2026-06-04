import Foundation
import SwiftData
import Observation
import MediaPlayer

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
        await engine.updateUnitSystem(appState.unitSystem == .imperial ? "imperial" : "metric")
        await engine.updateLoggingReminderInterval(TimeInterval(appState.restReminderSeconds))

        // Immediately broadcast current engine state when watch becomes reachable
        WatchSyncService.shared.onBecameReachable = { [weak self] in
            guard let self else { return }
            Task { await self.engine.broadcastCurrentState() }
        }

        // Reply to watch's "getState" pull requests with the current encoded state.
        // This is the primary reliability mechanism: watch asks on activation,
        // phone replies directly — no silent-failure paths.
        WatchSyncService.shared.stateProvider = { [weak self] replyHandler in
            guard let self else { replyHandler([:]); return }
            Task {
                let msg = await self.engine.buildCurrentStateMessage()
                guard let data = try? JSONEncoder().encode(msg) else {
                    replyHandler([:])
                    return
                }
                replyHandler(["state": data.base64EncodedString()])
            }
        }

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
    }

    private func handleWatchAction(_ msg: WatchActionMessage) async {
        switch msg.action {
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
        case "discard":
            await sessionVM.discardSession()
        case "mediaPrev":
            MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
        case "mediaPlayPause":
            let player = MPMusicPlayerController.systemMusicPlayer
            if player.playbackState == .playing { player.pause() } else { player.play() }
        case "mediaNext":
            MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
        default:
            break
        }
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
