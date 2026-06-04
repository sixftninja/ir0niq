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
        // engineState == "ending" is checked FIRST — live state must override any stale flag
        if vm.engineState == "ending" {
            WatchEndChoiceView()         // review screen → "Workout Ended" + Save/Discard
        } else if vm.showEndSummary {
            WatchEndSummaryView()        // saved → "Saved!" + Done
        } else if vm.showDiscarded {
            WatchDiscardedView()         // discarded → "Discarded" + Done
        } else if vm.isSessionActive {
            WatchActiveSessionView()
        } else {
            WatchHomeView()
        }
    }
}
