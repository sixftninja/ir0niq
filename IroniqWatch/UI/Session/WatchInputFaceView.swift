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
        VStack(spacing: 10) {
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
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            if primaryValue == 0, let hint = stepOnePlaceholder {
                Text("target: \(hint)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
            }

            Button("Next →") { step = .weight }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "E8680A"))
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("watch_next_button")
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Step 2: Weight

    private var weightStep: some View {
        VStack(spacing: 8) {
            Text("Weight")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            // Bodyweight toggle — full-width button for easy tapping
            Button {
                isBodyweight.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isBodyweight ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(isBodyweight ? Color(hex: "E8680A") : .secondary)
                    Text("Bodyweight")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isBodyweight ? .white : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.bordered)
            .tint(isBodyweight ? Color(hex: "E8680A") : .gray)

            if !isBodyweight {
                Text(weightDisplayText)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .focusable()
                    .digitalCrownRotation(
                        $weightValue,
                        from: 0,
                        through: isImperial ? 500 : 250,
                        by: isImperial ? 5 : 2.5,
                        sensitivity: .low,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
            }

            Button("Log Set") {
                submitLog()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2D7D4A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_done_button")
        }
        .padding(.horizontal, 8)
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
        primaryValue = 0
        if isImperial {
            // Round to nearest 5 lb; default 45 lb
            let raw = vm.targetWeight.map { $0 * 2.20462 } ?? 45
            weightValue = (raw / 5).rounded() * 5
        } else {
            // Round to nearest 2.5 kg; default 22.5 kg
            let raw = vm.targetWeight ?? 22.5
            weightValue = (raw / 2.5).rounded() * 2.5
        }
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
