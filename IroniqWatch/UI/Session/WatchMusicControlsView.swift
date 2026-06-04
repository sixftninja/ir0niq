import SwiftUI
import MediaPlayer

/// Music controls — reached by swiping right→left from the set face.
/// Controls send WCSession actions to the phone, which forwards them to the
/// system music player. Track title is read from the watch system's Now Playing.
struct WatchMusicControlsView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 12) {
            nowPlayingTitle

            HStack(spacing: 24) {
                transportButton(systemImage: "backward.fill") {
                    vm.sendMediaAction("mediaPrev")
                }
                .accessibilityIdentifier("watch_prev_track")

                transportButton(systemImage: "playpause.fill", color: Color(hex: "E8680A")) {
                    vm.sendMediaAction("mediaPlayPause")
                }
                .accessibilityIdentifier("watch_play_pause")

                transportButton(systemImage: "forward.fill") {
                    vm.sendMediaAction("mediaNext")
                }
                .accessibilityIdentifier("watch_next_track")
            }
        }
        .padding()
    }

    private var nowPlayingTitle: some View {
        Group {
            if let title = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String,
               !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("Music")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func transportButton(
        systemImage: String,
        color: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}
