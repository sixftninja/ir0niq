import SwiftUI

struct WatchEndConfirmView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("End Session?")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Your progress will be saved.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("End Session") {
                vm.confirmEndSession()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ironiqRed)
            .font(.subheadline)
            .accessibilityIdentifier("watch_confirm_end_button")

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
    }
}
