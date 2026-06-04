import SwiftUI

struct WatchReminderNudgeView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Finished Set?")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Button("Log it") {
                vm.showReminderNudge = false
                vm.showInputFace = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_reminder_log_button")

            Button("Skip Set") {
                vm.sendSkipSet()
                dismiss()
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
            .accessibilityIdentifier("watch_reminder_skip_button")
        }
        .padding(.horizontal, 8)
    }
}
