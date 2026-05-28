import SwiftUI

/// Reps and weight entry sheet.
struct InputFaceView: View {
    let set: ActiveSessionContext.ExerciseContext.SetContext
    let onLog: (Int?, Double?) -> Void

    @State private var reps: Int
    @State private var weight: Double
    @State private var noWeight = false
    @Environment(\.dismiss) private var dismiss

    init(set: ActiveSessionContext.ExerciseContext.SetContext, onLog: @escaping (Int?, Double?) -> Void) {
        self.set = set
        self.onLog = onLog
        _reps = State(initialValue: set.targetReps ?? 0)
        _weight = State(initialValue: set.targetWeight ?? 0)
        _noWeight = State(initialValue: set.targetWeight == nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Reps stepper
                stepperRow(
                    label: "Reps",
                    value: $reps,
                    range: 0...999,
                    step: 1
                )
                .accessibilityIdentifier("reps_picker")

                Divider().background(.white.opacity(0.1))

                // Weight stepper
                VStack(spacing: 8) {
                    stepperRow(
                        label: "Weight (kg)",
                        value: $weight,
                        range: 0...1000,
                        step: 2.5
                    )
                    .disabled(noWeight)
                    .opacity(noWeight ? 0.4 : 1)
                    .accessibilityIdentifier("weight_picker")

                    Toggle("Bodyweight (no weight)", isOn: $noWeight)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .toggleStyle(.switch)
                        .tint(.forgeOrange)
                }

                Spacer()

                ForgeButton("Log Set") {
                    onLog(reps > 0 ? reps : nil, noWeight ? nil : weight)
                }
                .accessibilityIdentifier("confirm_log_button")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .background(Color.forgeDark)
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onLog(nil, nil) }
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityIdentifier("skip_set_button")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.forgeOrange)
                }

                Text(step >= 1 ? "\(Int(value.wrappedValue))" : String(format: "%.1f", value.wrappedValue))
                    .font(.title2).bold().monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 60)

                Button {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.forgeOrange)
                }
            }
        }
    }

    // Convenience for Int steppers
    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) }
        )
        stepperRow(label: label, value: doubleBinding, range: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
    }
}
