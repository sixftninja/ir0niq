import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
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
    }
}
