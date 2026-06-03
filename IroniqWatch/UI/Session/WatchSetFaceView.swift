import SwiftUI

struct WatchSetFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            // Heart rate badge — top right, unobtrusive
            if let hr = vm.heartRate {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                    Text("\(Int(hr))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .padding(.top, 4)
                .padding(.trailing, 6)
            }

            if vm.isPaused {
                pausedContent
            } else {
                activeContent
            }
        }
    }

    private var activeContent: some View {
        VStack(spacing: 4) {
            if let name = vm.exerciseName {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("Set \(vm.setNumber)/\(vm.totalSets)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(vm.targetDisplayText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "E8680A"))

            Spacer().frame(height: 4)

            Button("Finish Set") {
                vm.sendFinishSet()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 14, weight: .bold))
            .accessibilityIdentifier("watch_finish_set_button")

            Button("Skip Set") {
                vm.sendSkipSet()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("watch_skip_set_button")
        }
        .padding(.horizontal, 4)
    }

    private var pausedContent: some View {
        VStack(spacing: 8) {
            Text("Set \(vm.setNumber)/\(vm.totalSets)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))

            Button("Resume") {
                vm.sendResume()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 14, weight: .bold))
            .accessibilityIdentifier("watch_resume_button")
        }
    }
}
