import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct IroniqComplicationEntry: TimelineEntry {
    let date: Date
    let isSessionActive: Bool
    let setNumber: Int?
    let totalSets: Int?
    let targetText: String?
}

// MARK: - Provider

struct IroniqComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> IroniqComplicationEntry {
        IroniqComplicationEntry(date: Date(), isSessionActive: false, setNumber: nil, totalSets: nil, targetText: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (IroniqComplicationEntry) -> Void) {
        completion(IroniqComplicationEntry(date: Date(), isSessionActive: false, setNumber: nil, totalSets: nil, targetText: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IroniqComplicationEntry>) -> Void) {
        let entry = IroniqComplicationEntry(date: Date(), isSessionActive: false, setNumber: nil, totalSets: nil, targetText: nil)
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
                if entry.isSessionActive, let set = entry.setNumber, let total = entry.totalSets {
                    VStack(spacing: 0) {
                        Text("\(set)/\(total)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text("SET")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color(hex: "E8680A"))
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color(hex: "E8680A"))
                    .font(.caption)
                if entry.isSessionActive, let set = entry.setNumber, let total = entry.totalSets {
                    Group {
                        Text("Set \(set)/\(total)")
                            .font(.system(.body, design: .monospaced).weight(.bold))
                        if let target = entry.targetText {
                            Text("· \(target)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
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
}

// MARK: - Color helper

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
