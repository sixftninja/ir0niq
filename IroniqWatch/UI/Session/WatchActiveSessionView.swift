import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @State private var selectedPage: Int = 1  // 0=controls, 1=set face, 2=music

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 0: Workout controls (swipe left→right from set face)
            WatchWorkoutControlsView()
                .tag(0)

            // Page 1: Active set face (default)
            WatchSetFaceView()
                .tag(1)

            // Page 2: Music controls (swipe right→left from set face)
            WatchMusicControlsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sheet(isPresented: Binding(
            get: { vm.showInputFace },
            set: { vm.showInputFace = $0 }
        )) {
            WatchInputFaceView()
        }
        .sheet(isPresented: Binding(
            get: { vm.showEndConfirm },
            set: { vm.showEndConfirm = $0 }
        )) {
            WatchEndConfirmView()
        }
        .sheet(isPresented: Binding(
            get: { vm.showReminderNudge },
            set: { vm.showReminderNudge = $0 }
        )) {
            WatchReminderNudgeView()
        }
    }
}
