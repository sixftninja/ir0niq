import SwiftUI

/// Reps/weight entry using the Digital Crown.
struct WatchInputFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var reps: Double = 0
    @State private var weight: Double = 0
    @State private var focusingReps = true

    var body: some View {
        VStack(spacing: 6) {
            // Mode selector
            HStack(spacing: 6) {
                modeButton("Reps", active: focusingReps) { focusingReps = true }
                modeButton("kg", active: !focusingReps) { focusingReps = false }
            }

            // Value display with Digital Crown binding
            Text(focusingReps
                 ? "\(Int(reps))"
                 : String(format: "%.1f", weight))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .focusable()
                .digitalCrownRotation(
                    focusingReps ? $reps : $weight,
                    from: 0,
                    through: focusingReps ? 50 : 400,
                    by: focusingReps ? 1 : 2.5,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Button("Done") {
                vm.logCurrentSet(reps: Int(reps), weight: weight)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.forgeGreen)
            .font(.headline)
            .accessibilityIdentifier("watch_done_button")
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func modeButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(active ? Color.forgeOrange : Color(white: 0.25))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
