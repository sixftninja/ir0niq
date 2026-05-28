import SwiftUI

struct PausedFaceView: View {
    @Environment(SessionViewModel.self) private var vm

    var body: some View {
        ZStack {
            Color.forgeDark.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.forgeOrange)

                Text("Session Paused")
                    .font(.title).bold()
                    .foregroundStyle(.white)

                Text(vm.sessionElapsed.timerFormatted)
                    .font(.system(size: 40, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                ForgeButton("Resume", style: .primary) {
                    Task { await vm.resumeSession() }
                }
                .accessibilityIdentifier("resume_button")
                .padding(.horizontal, 32)
            }
        }
    }
}
