import SwiftUI

struct WatchSetFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.isPaused {
                pausedContent
            } else {
                activeContent
            }
        }
    }

    private var activeContent: some View {
        VStack(spacing: 8) {

            // HR (left) + exercise name (truncated) in the same row
            HStack(spacing: 4) {
                if let hr = vm.heartRate {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                        Text("\(Int(hr))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .fixedSize()
                }
                if let name = vm.exerciseName {
                    Text(name)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Set \(vm.setNumber) / \(vm.totalSets)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(vm.targetDisplayText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "E8680A"))

            Spacer().frame(height: 2)

            Button("Finish Set") {
                vm.sendFinishSet()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_finish_set_button")

            // Skip: same readable font as before but minimal button footprint
            Button("Skip") {
                vm.sendSkipSet()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.vertical, 2)
            .accessibilityIdentifier("watch_skip_set_button")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)  // separation from the watch clock
        .padding(.bottom, 4)
    }

    private var pausedContent: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Set \(vm.setNumber) / \(vm.totalSets)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))

            Button("Resume") {
                vm.sendResume()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_resume_button")
        }
        .padding(.horizontal, 8)
    }
}
