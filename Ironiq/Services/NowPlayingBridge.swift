import Foundation
import MediaPlayer

/// Phone-side bridge for media control commands from the Watch.
///
/// Now Playing display: reads from MPNowPlayingInfoCenter which is populated by
/// any app (Spotify, Apple Music, YouTube Music, etc.) that publishes Now Playing info.
///
/// Transport commands: uses MPMusicPlayerController.systemMusicPlayer which controls
/// the active system music player. Works reliably with Apple Music; Spotify and other
/// apps work when they are registered as the system media controller.
@MainActor
final class NowPlayingBridge {
    static let shared = NowPlayingBridge()
    private init() {}

    private var player: MPMusicPlayerController { .systemMusicPlayer }

    func togglePlayPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func next() {
        player.skipToNextItem()
    }

    func previous() {
        if player.currentPlaybackTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
        }
    }

    /// Returns current Now Playing info from the system — works for any app that
    /// publishes Now Playing metadata (Spotify, Apple Music, YouTube Music, etc.).
    nonisolated func nowPlayingInfo() -> (title: String?, artist: String?) {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        return (
            info?[MPMediaItemPropertyTitle] as? String,
            info?[MPMediaItemPropertyArtist] as? String
        )
    }

    /// Pushes current Now Playing info to the Watch via WatchConnectivity.
    func broadcastNowPlayingToWatch() {
        let info = nowPlayingInfo()
        WatchSyncService.shared.sendNowPlayingUpdate([
            "type": "nowPlaying",
            "title": info.title ?? "",
            "artist": info.artist ?? ""
        ])
    }
}
