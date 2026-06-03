import SwiftUI

struct WatchReminderNudgeView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Log set?")
                .font(.headline)
                .foregroundStyle(.white)

            Button("Log") {
                vm.showReminderNudge = false
                vm.showInputFace = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.subheadline.weight(.bold))
            .accessibilityIdentifier("watch_reminder_log_button")

            Button("Skip") {
                vm.sendSkipSet()
                dismiss()
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .accessibilityIdentifier("watch_reminder_skip_button")
        }
        .padding()
    }
}
