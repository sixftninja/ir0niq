import SwiftUI

struct WatchEndConfirmView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("End workout?")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button("End Workout") {
                vm.requestEnd()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .font(.subheadline.weight(.bold))
            .accessibilityIdentifier("watch_confirm_end_button")

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
    }
}
