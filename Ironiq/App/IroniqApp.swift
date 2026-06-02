import SwiftData
import SwiftUI

@main
struct IroniqApp: App {
  private let startup: AppStartup

  init() {
    startup = AppStartup.make()
  }

  var body: some Scene {
    WindowGroup {
      switch startup {
      case .ready(let container, let appModel):
        ContentView()
          .modelContainer(container)
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
            await appModel.performStartupSync()
            // UI test helper: auto-start an ad-hoc session for session UI verification
            if CommandLine.arguments.contains("--start-adhoc-session") {
              await appModel.sessionVM.startAdHocSession()
            }
          }
      case .failed(let message):
        StartupRecoveryView(message: message)
      }
    }
  }
}

@MainActor
private enum AppStartup {
  case ready(ModelContainer, AppModel)
  case failed(String)

  static func make() -> AppStartup {
    do {
      let container = try ModelContainerFactory.makeSharedContainer()
      return .ready(container, AppModel(modelContainer: container))
    } catch {
      let persistentError = error
      do {
        let container = try ModelContainerFactory.makeRebuiltSharedContainer()
        return .ready(container, AppModel(modelContainer: container))
      } catch {
        let rebuildError = error
        do {
          let container = try ModelContainerFactory.makeInMemoryContainer()
          return .ready(container, AppModel(modelContainer: container))
        } catch {
          return .failed(
            "Ironiq could not open its local workout database. Persistent store error: \(persistentError.localizedDescription). Rebuild error: \(rebuildError.localizedDescription). Recovery store error: \(error.localizedDescription)."
          )
        }
      }
    }
  }
}

private struct StartupRecoveryView: View {
  let message: String

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 44, weight: .semibold))
          .foregroundStyle(Color.orange)
        Text("Ironiq couldn't open")
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.white)
        Text(
          "Your workout data could not be loaded on this launch. Please send this screen to support, then reinstall Ironiq from TestFlight to rebuild the local store."
        )
        .font(.body)
        .foregroundStyle(.white.opacity(0.72))
        Text(message)
          .font(.footnote.monospaced())
          .foregroundStyle(.white.opacity(0.5))
          .textSelection(.enabled)
          .padding(.top, 8)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
