import SwiftUI

@main
struct IroniqWatchApp: App {
    @State private var sessionVM = WatchSessionViewModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(sessionVM)
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        if vm.engineState == "ending" || vm.showEndSummary || vm.showDiscarded {
            WatchWorkoutEndedView()      // single acknowledgment screen for all end states
        } else if vm.isSessionActive {
            WatchActiveSessionView()
        } else {
            WatchHomeView()
        }
    }
}
