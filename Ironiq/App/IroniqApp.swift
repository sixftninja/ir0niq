import SwiftData
import SwiftUI

@main
struct IroniqApp: App {
  private let modelContainer: ModelContainer
  @State private var appModel: AppModel

  init() {
    let container: ModelContainer
    do {
      container = try ModelContainerFactory.makeSharedContainer()
    } catch {
      // A persistent store failure should not brick the app on launch.
      // Fall back to an in-memory store so the user can still open Ironiq
      // and reconnect cloud sync while we preserve the crash-free path.
      container =
        (try? ModelContainerFactory.makeInMemoryContainer())
        ?? {
          fatalError("Unable to open any SwiftData store: \(error)")
        }()
    }
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
