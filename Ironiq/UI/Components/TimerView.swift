import SwiftUI

/// Large, monospaced timer display. `value` is the TimeInterval to display.
struct TimerView: View {
    let value: TimeInterval
    var color: Color = .white
    var font: Font = .system(size: 64, weight: .bold, design: .monospaced)

    var body: some View {
        Text(value.timerFormatted)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(countsDown: false))
            .monospacedDigit()
            .accessibilityLabel("Timer: \(value.timerFormatted)")
    }
}

/// Compact rest countdown. Shows overtime in red when past target.
struct RestTimerView: View {
    let remaining: TimeInterval
    let elapsed: TimeInterval
    let hasTarget: Bool

    var body: some View {
        VStack(spacing: 4) {
            if hasTarget {
                TimerView(
                    value: remaining,
                    color: remaining > 0 ? Color.white : Color.ironiqRed
                )
                if remaining <= 0 {
                    Text(elapsed.overtimeFormatted)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.ironiqRed)
                }
            } else {
                TimerView(value: elapsed)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TimerView(value: 65)
        RestTimerView(remaining: 30, elapsed: 60, hasTarget: true)
        RestTimerView(remaining: 0, elapsed: 125, hasTarget: true)
    }
    .padding()
    .background(Color.ironiqDark)
}
