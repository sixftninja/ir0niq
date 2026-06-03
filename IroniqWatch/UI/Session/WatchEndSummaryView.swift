import SwiftUI

struct WatchEndSummaryView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 10) {
            Text("Workout\nComplete")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text(durationText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "E8680A"))
                Text(volumeText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Save") { vm.sendSave() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "2D7D4A"))
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("watch_save_button")

                Button("Discard") { vm.sendDiscard() }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .font(.subheadline)
                    .accessibilityIdentifier("watch_discard_button")
            }
        }
        .padding(.horizontal, 4)
    }

    private var durationText: String {
        let total = Int(vm.sessionDurationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }

    private var volumeText: String {
        if vm.unitSystem == "imperial" {
            let lb = vm.sessionVolumeKg * 2.20462
            return String(format: "%.0f lb", lb)
        }
        return String(format: "%.0f kg", vm.sessionVolumeKg)
    }
}
