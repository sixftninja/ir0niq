import SwiftUI

/// Simple acknowledgment shown whenever a workout ends (saved, discarded, or ending state).
/// No choices — phone handles save/discard. User just taps Done to return to idle.
struct WatchWorkoutEndedView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 16) {
            Text("Workout\nEnded")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button("Done") {
                vm.dismissWorkoutEnded()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_workout_ended_done_button")
        }
        .padding(.horizontal, 8)
    }
}

/// Shown after a workout is saved — displays duration + volume, then returns to idle.
struct WatchEndSummaryView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 10) {
            Text("Saved!")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(hex: "2D7D4A"))

            VStack(spacing: 4) {
                Text(durationText)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "E8680A"))
                Text(volumeText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                vm.dismissEndSummary()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2D7D4A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_done_button")
        }
        .padding(.horizontal, 8)
    }

    private var durationText: String {
        let total = Int(vm.sessionDurationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private var volumeText: String {
        if vm.sessionVolumeKg <= 0 { return "Bodyweight" }
        if vm.unitSystem == "imperial" {
            let lb = vm.sessionVolumeKg * 2.20462
            return String(format: "%.0f lb", lb)
        }
        return String(format: "%.0f kg", vm.sessionVolumeKg)
    }
}

/// Shown when phone discards the workout — passive confirmation with Done button.
struct WatchDiscardedView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 12) {
            Text("Discarded")
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)

            Button("Done") {
                vm.dismissDiscarded()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
    }
}

/// Shown when phone ends and is on the review screen — watch is a passive observer.
struct WatchEditInProgressView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("Edit in\nProgress")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Finish on iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when engine is in "ending" state — lets user choose to save or discard.
struct WatchEndChoiceView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 12) {
            Text("Workout Ended")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Button("Save") {
                vm.saveFromWatch()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "2D7D4A"))
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_save_button")

            Button("Discard") {
                vm.discardFromWatch()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("watch_discard_button")
        }
        .padding(.horizontal, 8)
    }
}
