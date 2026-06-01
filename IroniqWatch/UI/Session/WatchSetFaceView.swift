import SwiftUI

struct WatchSetFaceView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        ZStack {
            // Red heart-rate outline when HR is available
            if vm.heartRate != nil {
                Circle()
                    .stroke(Color.ironiqRed, lineWidth: 3)
                    .padding(1)
            }

            VStack(spacing: 2) {
                // Exercise name
                Text(vm.exerciseName ?? "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Set number
                Text("Set \(vm.setNumber)/\(vm.totalSets)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // Large set timer (when in progress)
                if vm.setStatus == "inProgress" {
                    Text(vm.setElapsed.timerFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ironiqOrange)
                        .accessibilityIdentifier("watch_set_timer")
                } else {
                    // Placeholder when pending
                    Text("0:00")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }

                // Heart rate
                if let hr = vm.heartRate {
                    Label("\(Int(hr))", systemImage: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ironiqRed)
                }
            }
        }
        .overlay(alignment: .bottom) {
            actionButton
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch vm.setStatus {
        case "pending":
            Button("Begin") { vm.sendBeginSet() }
                .buttonStyle(.borderedProminent)
                .tint(Color.ironiqOrange)
                .font(.headline)
                .accessibilityIdentifier("watch_begin_button")

        case "inProgress":
            Button("Rest") { vm.sendRest() }
                .buttonStyle(.borderedProminent)
                .tint(Color.ironiqOrange)
                .font(.headline)
                .accessibilityIdentifier("watch_rest_button")

        case "logged":
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.ironiqGreen)

        default:
            EmptyView()
        }
    }
}
