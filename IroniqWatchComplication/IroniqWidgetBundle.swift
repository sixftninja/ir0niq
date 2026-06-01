import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct IroniqComplicationEntry: TimelineEntry {
    let date: Date
    let isSessionActive: Bool
    let sessionElapsed: TimeInterval?
}

// MARK: - Provider

struct IroniqComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> IroniqComplicationEntry {
        IroniqComplicationEntry(date: Date(), isSessionActive: false, sessionElapsed: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (IroniqComplicationEntry) -> Void) {
        completion(IroniqComplicationEntry(date: Date(), isSessionActive: false, sessionElapsed: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IroniqComplicationEntry>) -> Void) {
        let entry = IroniqComplicationEntry(date: Date(), isSessionActive: false, sessionElapsed: nil)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Complication view

struct IroniqComplicationView: View {
    let entry: IroniqComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color(hex: "E8680A"))
            }
        case .accessoryRectangular:
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color(hex: "E8680A"))
                    .font(.caption)
                if let elapsed = entry.sessionElapsed {
                    Text(timerString(elapsed))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                } else {
                    Text("Ironiq")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        case .accessoryCorner:
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Color(hex: "E8680A"))
        default:
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(Color(hex: "E8680A"))
        }
    }

    private func timerString(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Color helper (duplicated — no shared framework in Phase 4)

extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Widget

struct IroniqComplication: Widget {
    let kind = "IroniqComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IroniqComplicationProvider()) { entry in
            IroniqComplicationView(entry: entry)
        }
        .configurationDisplayName("Ironiq")
        .description("Quick access to your workout.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

// MARK: - Bundle entry point

@main
struct IroniqWidgetBundle: WidgetBundle {
    var body: some Widget { IroniqComplication() }
}
