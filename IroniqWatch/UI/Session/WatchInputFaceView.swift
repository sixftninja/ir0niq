import SwiftUI

/// One-screen log: reps/duration + weight, Crown scrolls active field.
struct WatchInputFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var primaryValue: Double = 0   // reps or seconds
    @State private var weightKg: Double = 0
    @State private var focusingPrimary = true

    var body: some View {
        VStack(spacing: 6) {
            // Field selector tabs
            HStack(spacing: 4) {
                fieldTab(vm.loggingType == "duration" ? "Sec" : "Reps", active: focusingPrimary) {
                    focusingPrimary = true
                }
                fieldTab("Weight", active: !focusingPrimary) {
                    focusingPrimary = false
                }
            }

            // Active value — Crown controls this
            if focusingPrimary {
                Text(primaryDisplayText)
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .focusable()
                    .digitalCrownRotation(
                        $primaryValue,
                        from: 0,
                        through: vm.loggingType == "duration" ? 3600 : 100,
                        by: vm.loggingType == "duration" ? 5 : 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
            } else {
                Text(vm.weightText(kg: weightKg))
                    .font(.system(size: weightKg <= 0 ? 20 : 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .focusable()
                    .digitalCrownRotation(
                        $weightKg,
                        from: 0,
                        through: 500,
                        by: 0.5,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
            }

            Button("Done") {
                vm.logCurrentSet(
                    reps: Int(primaryValue),
                    durationSeconds: primaryValue,
                    weight: weightKg
                )
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2D7D4A"))
            .font(.headline)
            .accessibilityIdentifier("watch_done_button")
        }
        .padding(.horizontal, 4)
        .onAppear { loadDefaults() }
    }

    private var primaryDisplayText: String {
        if vm.loggingType == "duration" {
            let secs = Int(primaryValue)
            return secs >= 60 ? "\(secs / 60):\(String(format: "%02d", secs % 60))" : "\(secs)"
        }
        return "\(Int(primaryValue))"
    }

    private func loadDefaults() {
        if vm.loggingType == "duration" {
            primaryValue = vm.targetDuration ?? 0
        } else {
            primaryValue = Double(vm.targetReps ?? 0)
        }
        weightKg = vm.targetWeight ?? 0
    }

    private func fieldTab(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(active ? Color(hex: "E8680A") : Color(white: 0.2))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
