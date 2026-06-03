import SwiftUI

/// Workout-level controls — shown by swiping left→right from the set face.
struct WatchWorkoutControlsView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 12) {
            if vm.isPaused {
                Text("Paused")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                Button("Resume") { vm.sendResume() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "E8680A"))
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("watch_controls_resume_button")
            } else {
                Text("Workout")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                Button("Pause") { vm.sendPause() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "E8680A"))
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("watch_pause_button")
            }

            Button("End") { vm.showEndConfirm = true }
                .buttonStyle(.bordered)
                .tint(.red)
                .font(.subheadline)
                .accessibilityIdentifier("watch_end_button")
        }
        .padding()
    }
}
