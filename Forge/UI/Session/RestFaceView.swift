import SwiftUI

/// Shown while the current set is resting.
struct RestFaceView: View {
    @Environment(SessionViewModel.self) private var vm
    let set: ActiveSessionContext.ExerciseContext.SetContext

    @State private var reps: Int = 0
    @State private var weight: Double = 0
    @State private var showInput = false

    var body: some View {
        VStack(spacing: 0) {
            Text("REST")
                .font(.caption).bold()
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
                .padding(.top, 8)

            Spacer()

            RestTimerView(
                remaining: vm.restRemaining,
                elapsed: vm.restElapsed,
                hasTarget: vm.hasRestTarget
            )
            .accessibilityIdentifier("rest_timer")

            if vm.hasRestTarget && vm.restRemaining <= 0 {
                Text("Time to log your set!")
                    .font(.subheadline)
                    .foregroundStyle(Color.forgeGreen)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: 12) {
                // Log early button
                ForgeButton("Log Set", style: .primary) {
                    showInput = true
                }
                .accessibilityIdentifier("log_set_button")

                // Next set preview
                if let targetReps = set.targetReps {
                    Text("Next: \(targetReps) reps" + (set.targetWeight.map { String(format: " @ %.0f kg", $0) } ?? ""))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showInput) {
            InputFaceView(set: set, onLog: { r, w in
                Task {
                    await vm.logCurrentSet(reps: r, weight: w)
                    showInput = false
                }
            })
            .presentationDetents([.medium])
        }
        .onAppear {
            reps = set.targetReps ?? 0
            weight = set.targetWeight ?? 0
        }
    }
}
