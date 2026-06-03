import SwiftUI
import MediaPlayer

/// Music controls — reached by swiping right→left from the set face.
/// MPRemoteCommandCenter handlers are registered once at app init.
/// Buttons send commands via MPRemoteCommandCenter (watchOS-compatible).
struct WatchMusicControlsView: View {
    var body: some View {
        VStack(spacing: 10) {
            if let title = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            } else {
                Text("Music")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                transportButton(systemImage: "backward.fill") {
                    MPRemoteCommandCenter.shared().previousTrackCommand
                        .addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_prev_track")

                transportButton(systemImage: "playpause.fill", color: Color(hex: "E8680A")) {
                    MPRemoteCommandCenter.shared().togglePlayPauseCommand
                        .addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_play_pause")

                transportButton(systemImage: "forward.fill") {
                    MPRemoteCommandCenter.shared().nextTrackCommand
                        .addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_next_track")
            }
        }
        .padding()
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
