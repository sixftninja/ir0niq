import SwiftUI

/// Shown when current set is pending or inProgress.
struct SetFaceView: View {
    @Environment(SessionViewModel.self) private var vm
    let set: ActiveSessionContext.ExerciseContext.SetContext

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Set timer (shown while inProgress)
            if case .inProgress = set.lifecycleState {
                VStack(spacing: 8) {
                    Text("SET TIME")
                        .font(.caption).bold()
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                    TimerView(value: vm.setElapsed, color: .ironiqOrange)
                        .accessibilityIdentifier("set_timer")
                }
                .transition(.opacity)
            } else {
                // Pending state: show target info
                VStack(spacing: 12) {
                    if let targetReps = set.targetReps {
                        targetPill("\(targetReps) reps")
                    }
                    if let targetWeight = set.targetWeight {
                        targetPill(String(format: "%.0f kg", targetWeight))
                    }
                }
            }

            Spacer()

            // Primary action
            if case .pending = set.lifecycleState {
                IroniqButton("Begin Set", style: .primary) {
                    Task { await vm.beginCurrentSet() }
                }
                .accessibilityIdentifier("begin_set_button")
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else if case .inProgress = set.lifecycleState {
                VStack(spacing: 12) {
                    IroniqButton("Rest", style: .secondary) {
                        Task { await vm.tapRest() }
                    }
                    .accessibilityIdentifier("rest_button")

                    // Allow logging without rest
                    Button("Log without rest") {
                        Task { await vm.logCurrentSet(reps: set.targetReps, weight: set.targetWeight) }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityIdentifier("log_without_rest_button")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: set.lifecycleState == .pending)
    }

    private func targetPill(_ text: String) -> some View {
        Text(text)
            .font(.title2).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color(white: 0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Shared button styles

struct IroniqButton: View {
    enum Style { case primary, secondary }
    let title: String
    let style: Style
    let action: () -> Void

    init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(style == .primary ? .black : Color.ironiqOrange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(style == .primary ? Color.ironiqOrange : Color.ironiqOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style == .secondary ? Color.ironiqOrange.opacity(0.4) : .clear, lineWidth: 1)
                )
        }
    }
}
