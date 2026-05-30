import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let modelContainer: ModelContainer
    @State private var appModel: AppModel

    init() {
        // makeSharedContainer auto-recovers from schema mismatches by wiping the store.
        // If even that fails, fall back to in-memory so the app never brick-loops.
        let container = (try? ModelContainerFactory.makeSharedContainer())
            ?? (try! ModelContainerFactory.makeInMemoryContainer())
        modelContainer = container
        _appModel = State(wrappedValue: AppModel(modelContainer: container))
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
                .preferredColorScheme(appModel.appState.useDarkMode ? .dark : .light)
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
