import SwiftUI
import MediaPlayer

@main
struct IroniqWatchApp: App {
    @State private var sessionVM = WatchSessionViewModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(sessionVM)
        }
    }

    init() {
        setupMusicControls()
    }

    private func setupMusicControls() {
        // Enable the commands so external devices (like this watch app) can be a
        // remote-control target. The system routes these to the active audio app.
        let center = MPRemoteCommandCenter.shared()
        center.previousTrackCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        // Handlers intentionally left empty — commands propagate to the audio app.
        center.previousTrackCommand.addTarget { _ in .success }
        center.nextTrackCommand.addTarget { _ in .success }
        center.togglePlayPauseCommand.addTarget { _ in .success }
    }
}

struct WatchRootView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        if vm.showEndSummary {
            WatchEndSummaryView()
        } else if vm.isSessionActive {
            WatchActiveSessionView()
        } else {
            WatchTemplateListView()
        }
    }
}
