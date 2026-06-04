import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)

            Text("Open Ironiq\non iPhone to\nstart a workout")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WatchHomeView()
}
