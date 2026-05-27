import SwiftUI

@main
struct ForgeWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    var body: some View {
        Text("Forge")
            .foregroundStyle(Color.forgeOrange)
    }
}
