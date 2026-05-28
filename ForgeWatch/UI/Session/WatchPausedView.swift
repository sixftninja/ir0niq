import SwiftUI

struct WatchPausedView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.forgeOrange)

            Text("Paused")
                .font(.headline)
                .foregroundStyle(.white)

            Button("Resume") { vm.sendResume() }
                .buttonStyle(.borderedProminent)
                .tint(Color.forgeOrange)
                .font(.subheadline)
                .accessibilityIdentifier("watch_resume_button")
        }
    }
}
