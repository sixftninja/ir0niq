import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.forgeOrange)

            Text("Forge")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Start a workout on\nyour iPhone")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier("watch_home_view")
    }
}

#Preview {
    WatchHomeView()
        .environment(WatchSessionViewModel())
}
