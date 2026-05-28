import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        TabView {
            // Main session face (swipe left for music)
            sessionFace
                .tag(0)

            // Music controls (swipe right)
            WatchMusicControlsView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sheet(isPresented: Binding(
            get: { vm.showEndConfirm },
            set: { _ in }
        )) {
            WatchEndConfirmView()
        }
    }

    @ViewBuilder
    private var sessionFace: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isPaused {
                WatchPausedView()
            } else {
                switch vm.setStatus {
                case "resting":
                    WatchRestFaceView()
                case "awaitingInput":
                    WatchInputFaceView()
                default:
                    WatchSetFaceView()
                }
            }
        }
    }
}
