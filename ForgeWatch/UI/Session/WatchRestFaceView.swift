import SwiftUI

struct WatchRestFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        ZStack {
            // On-time celebration: green ring + checkmark flash
            if vm.showCelebration {
                ZStack {
                    Circle()
                        .stroke(Color.forgeGreen, lineWidth: 5)
                        .padding(2)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.forgeGreen)
                }
                .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 2) {
                Text("REST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                // Countdown timer
                if vm.hasRestTarget && vm.restRemaining > 0 {
                    Text(vm.restRemaining.timerFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("watch_rest_timer")
                } else if vm.hasRestTarget && vm.restRemaining <= 0 {
                    // Overtime
                    Text(vm.restElapsed.timerFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.forgeRed)
                } else {
                    // No target — show elapsed
                    Text(vm.restElapsed.timerFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Button("Log Set") {
                    vm.showInputFace = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.forgeOrange)
                .font(.subheadline)
                .accessibilityIdentifier("watch_log_set_button")
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showInputFace },
            set: { vm.showInputFace = $0 }
        )) {
            WatchInputFaceView()
        }
    }
}
