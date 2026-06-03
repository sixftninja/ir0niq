import SwiftUI

/// Two-step log flow: Step 1 = reps or duration, Step 2 = weight.
struct WatchInputFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .primary
    @State private var primaryValue: Double = 0
    @State private var isBodyweight: Bool = false
    @State private var weightValue: Double = 0  // in user's unit (lbs or kg)

    enum Step { case primary, weight }

    // MARK: - Body

    var body: some View {
        Group {
            switch step {
            case .primary: primaryStep
            case .weight: weightStep
            }
        }
        .onAppear { loadDefaults() }
    }

    // MARK: - Step 1: Reps or Duration

    private var primaryStep: some View {
        VStack(spacing: 6) {
            Text(stepOneLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            Text(primaryDisplayText)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
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

            // Placeholder hint
            if primaryValue == 0, let hint = stepOnePlaceholder {
                Text("target: \(hint)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
            }

            Button("Next") { step = .weight }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "E8680A"))
                .font(.system(size: 14, weight: .bold))
                .accessibilityIdentifier("watch_next_button")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Step 2: Weight

    private var weightStep: some View {
        VStack(spacing: 6) {
            Text("Weight")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            // Bodyweight toggle
            Button {
                isBodyweight.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isBodyweight ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isBodyweight ? Color(hex: "E8680A") : .secondary)
                    Text("Bodyweight")
                        .font(.system(size: 11))
                        .foregroundStyle(isBodyweight ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)

            if !isBodyweight {
                Text(weightDisplayText)
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .focusable()
                    .digitalCrownRotation(
                        $weightValue,
                        from: 0,
                        through: isImperial ? 5000 : 2267,
                        by: isImperial ? 5 : 2.5,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
            }

            Button("Done") {
                submitLog()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2D7D4A"))
            .font(.system(size: 14, weight: .bold))
            .accessibilityIdentifier("watch_done_button")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var isImperial: Bool { vm.unitSystem == "imperial" }

    private var stepOneLabel: String {
        vm.loggingType == "duration" ? "Duration (sec)" : "Reps"
    }

    private var stepOnePlaceholder: String? {
        if vm.loggingType == "duration", let d = vm.targetDuration {
            let s = Int(d)
            return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s) sec"
        }
        if let r = vm.targetReps { return "\(r) reps" }
        return nil
    }

    private var primaryDisplayText: String {
        if primaryValue == 0 { return "0" }
        if vm.loggingType == "duration" {
            let s = Int(primaryValue)
            return s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)"
        }
        return "\(Int(primaryValue))"
    }

    private var weightDisplayText: String {
        let val = weightValue
        if val <= 0 { return isImperial ? "0 lb" : "0 kg" }
        if isImperial { return String(format: "%.0f lb", val) }
        return String(format: "%.1f kg", val)
    }

    private func loadDefaults() {
        // Start at 0 — target shown as placeholder
        primaryValue = 0

        // Weight: start at 45 lb / 20 kg, respect existing target if set
        if isImperial {
            weightValue = vm.targetWeight.map { $0 * 2.20462 } ?? 45
        } else {
            weightValue = vm.targetWeight ?? 20
        }
        // If target weight is explicitly 0, treat as bodyweight
        if let tw = vm.targetWeight, tw <= 0 { isBodyweight = true }
    }

    private func submitLog() {
        let repsVal: Int? = vm.loggingType == "reps" && primaryValue > 0 ? Int(primaryValue) : nil
        let durVal: TimeInterval? = vm.loggingType == "duration" && primaryValue > 0 ? primaryValue : nil
        let weightKg: Double? = isBodyweight ? nil : (isImperial ? weightValue / 2.20462 : weightValue)
        vm.logCurrentSet(reps: repsVal ?? 0, durationSeconds: durVal ?? 0, weight: weightKg ?? 0)
        dismiss()
    }
}
