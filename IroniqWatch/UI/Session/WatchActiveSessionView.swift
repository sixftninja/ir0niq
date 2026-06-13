import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        TabView {
            // Left panel — Pause screen
            WatchPauseView()
                .tag(0)

            // Center — Active set face (default)
            WatchSetFaceView()
                .sheet(isPresented: Binding(
                    get: { vm.showInputFace },
                    set: { vm.showInputFace = $0 }
                )) {
                    WatchInputFaceView()
                }
                .sheet(isPresented: Binding(
                    get: { vm.showReminderNudge },
                    set: { vm.showReminderNudge = $0 }
                )) {
                    WatchReminderNudgeView()
                }
                .tag(1)

            // Right panel — Music controls
            WatchMusicControlsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .defaultScrollAnchor(.center)
    }
}
