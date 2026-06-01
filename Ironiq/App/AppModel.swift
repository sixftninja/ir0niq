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

    init(modelContainer: ModelContainer) {
        let appState = AppState()
        self.appState = appState

        let engine = SessionEngine.make(modelContainer: modelContainer)
        self.engine = engine
        SessionEngine.current = engine   // for AppIntents in-process access

        let templateRepo = TemplateRepository(modelContainer: modelContainer)
        let exerciseRepo = ExerciseRepository(modelContainer: modelContainer)
        let sessionRepo = SessionRepository(modelContainer: modelContainer)

        self.sessionVM = SessionViewModel(engine: engine)
        self.templateVM = TemplateViewModel(templateRepo: templateRepo, exerciseRepo: exerciseRepo)
        self.historyVM = HistoryViewModel(sessionRepo: sessionRepo, appState: appState)
        self.settingsVM = SettingsViewModel()
        self.storeKit = StoreKitService.shared

        // Initialize StoreKit (non-blocking — happens in background)
        Task { await StoreKitService.shared.initialize(appState: appState) }
    }
}
