import SwiftUI
import MediaPlayer

/// Music controls accessible by swiping right from the active session face.
struct WatchMusicControlsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundStyle(Color.ironiqOrange)

            Text("Music")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                transportButton(systemImage: "backward.fill") {
                    MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = true
                    MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_prev_track")

                transportButton(systemImage: "playpause.fill", color: .ironiqOrange) {
                    MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
                    MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_play_pause")

                transportButton(systemImage: "forward.fill") {
                    MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
                    MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { _ in .success }
                }
                .accessibilityIdentifier("watch_next_track")
            }
        }
        .padding()
    }

    @ViewBuilder
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
