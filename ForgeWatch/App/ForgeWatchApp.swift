import SwiftUI

@main
struct ForgeWatchApp: App {
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
        if vm.isSessionActive {
            WatchActiveSessionView()
        } else {
            WatchHomeView()
        }
    }
}
