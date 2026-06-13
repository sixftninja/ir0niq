import SwiftUI

struct WatchPauseView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 14) {
            Text("PAUSED")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(3)

            VStack(spacing: 4) {
                Text(vm.sessionDurationSeconds.timerFormatted)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))

                if let exercise = vm.exerciseName {
                    Text(exercise)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    Text("Set \(vm.setNumber) of \(vm.totalSets)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Button {
                vm.sendResume()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "E8680A"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("watch_resume_button")
        }
        .padding()
    }
}
