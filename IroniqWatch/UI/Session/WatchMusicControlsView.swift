import MediaPlayer
import SwiftUI

/// Music controls screen — swiped to from the active set face.
///
/// Now Playing display: reads from MPNowPlayingInfoCenter.default() which reflects
/// whatever is playing on the paired iPhone (any app that publishes Now Playing info).
/// Transport commands: sent to the phone via WCSession, where NowPlayingBridge forwards
/// them to MPMusicPlayerController.systemMusicPlayer.
struct WatchMusicControlsView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @State private var nowPlayingTitle: String? = nil
    @State private var nowPlayingArtist: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            nowPlayingInfo

            HStack(spacing: 20) {
                transportButton(systemImage: "backward.fill") {
                    vm.sendMediaAction("mediaPrev")
                }
                .accessibilityIdentifier("watch_prev_track")

                transportButton(systemImage: "playpause.fill", color: Color(hex: "E8680A"), large: true) {
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
        .onAppear { refreshNowPlaying() }
        .task {
            // Poll NowPlaying info every 3 seconds to keep display fresh
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                refreshNowPlaying()
            }
        }
    }

    private var nowPlayingInfo: some View {
        VStack(spacing: 2) {
            if let title = nowPlayingTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let artist = nowPlayingArtist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            } else {
                Text("Music")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func transportButton(
        systemImage: String,
        color: Color = .white,
        large: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(large ? .title3 : .body)
                .foregroundStyle(color)
                .frame(width: large ? 36 : 28, height: large ? 36 : 28)
        }
        .buttonStyle(.plain)
    }

    private func refreshNowPlaying() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        nowPlayingTitle = info?[MPMediaItemPropertyTitle] as? String
        nowPlayingArtist = info?[MPMediaItemPropertyArtist] as? String
    }
}
