import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let modelContainer: ModelContainer
    @State private var appModel: AppModel

    init() {
        do {
            let container = try ModelContainerFactory.makeSharedContainer()
            modelContainer = container
            _appModel = State(wrappedValue: AppModel(modelContainer: container))
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(appModel)
                .environment(appModel.appState)
                .environment(appModel.sessionVM)
                .environment(appModel.templateVM)
                .environment(appModel.historyVM)
                .environment(appModel.settingsVM)
                .environment(appModel.storeKit)
                .task {
                    await appModel.templateVM.seedExercisesIfNeeded()
                    await appModel.templateVM.loadAll()
                    await appModel.historyVM.loadSessions()
                    // UI test helper: auto-start an ad-hoc session for session UI verification
                    if CommandLine.arguments.contains("--start-adhoc-session") {
                        await appModel.sessionVM.startAdHocSession()
                    }
                }
        }
    }
}
