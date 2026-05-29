import SwiftUI

/// Reps and weight entry sheet.
struct InputFaceView: View {
    let set: ActiveSessionContext.ExerciseContext.SetContext
    let onLog: (Int?, Double?) -> Void

    @Environment(AppState.self) private var appState
    @State private var reps: Int
    @State private var displayWeight: Double   // in user's unit system
    @State private var noWeight = false
    @Environment(\.dismiss) private var dismiss

    init(set: ActiveSessionContext.ExerciseContext.SetContext, onLog: @escaping (Int?, Double?) -> Void) {
        self.set = set
        self.onLog = onLog
        _reps = State(initialValue: set.targetReps ?? 0)
        // Default display weight: we store in kg, convert on init via AppState at render time
        _displayWeight = State(initialValue: set.targetWeight ?? 0)
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
                        label: "Weight (\(WeightFormatter.unitLabel(appState.unitSystem)))",
                        value: $displayWeight,
                        range: 0...WeightFormatter.maxWeight(appState.unitSystem),
                        step: WeightFormatter.stepSize(appState.unitSystem)
                    )
                    .disabled(noWeight)
                    .opacity(noWeight ? 0.4 : 1)
                    .accessibilityIdentifier("weight_picker")

                    Toggle("Bodyweight / no load", isOn: $noWeight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .toggleStyle(.switch)
                        .tint(.forgeOrange)
                }

                Spacer()

                ForgeButton("Log Set") {
                    let kgWeight = noWeight ? nil : WeightFormatter.toKg(displayWeight, unitSystem: appState.unitSystem)
                    onLog(reps > 0 ? reps : nil, kgWeight)
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
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("skip_set_button")
                }
            }
        }
        .onAppear {
            // Convert stored kg to display unit once AppState is available
            if let kg = set.targetWeight {
                displayWeight = WeightFormatter.fromKg(kg, unitSystem: appState.unitSystem)
            }
        }
    }

    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundStyle(.primary)
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
                .accessibilityLabel("Decrease \(label)")

                Text(step >= 1 ? "\(Int(value.wrappedValue))" : String(format: "%.1f", value.wrappedValue))
                    .font(.title2).bold().monospacedDigit()
                    .foregroundStyle(.primary)
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
                .accessibilityLabel("Increase \(label)")
            }
        }
    }

    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) }
        )
        stepperRow(label: label, value: doubleBinding,
                   range: Double(range.lowerBound)...Double(range.upperBound),
                   step: Double(step))
    }
}
