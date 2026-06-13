import Charts
import SwiftUI

// MARK: - Analytics Tab

struct AnalyticsView: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(AppState.self) private var appState
    @State private var expandedBox: AnalyticsBox? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                        spacing: 12
                    ) {
                        analyticsBox(.consistency)
                        analyticsBox(.totalWeight)
                        analyticsBox(.muscleBalance)
                        analyticsBox(.maxWeight)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .padding(.bottom, 100)
            }
            .background(Color.ironiqDark)
            .navigationBarHidden(true)
        }
        .sheet(item: $expandedBox) { box in
            AnalyticsDetailView(box: box)
                .environment(historyVM)
                .environment(appState)
        }
    }

    private func analyticsBox(_ box: AnalyticsBox) -> some View {
        let metric = boxMetric(box)
        return Button { expandedBox = box } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(box.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(metric.value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let sub = metric.subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("analytics_box_\(box.title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    // MARK: - Metric calculations

    private struct BoxMetric { let value: String; let subtitle: String? }

    private func boxMetric(_ box: AnalyticsBox) -> BoxMetric {
        let activeSessions = historyVM.sessions.filter { !$0.isFromArchivedTemplate }
        switch box {
        case .consistency:
            let target = max(1, appState.sessionsPerWeekTarget)
            let pct = consistencyPct(sessions: activeSessions, target: target)
            return BoxMetric(value: "\(pct)%", subtitle: "4-week rolling avg")
        case .totalWeight:
            let allSets = activeSessions.flatMap { s in s.exercises.flatMap { e in e.sets } }
            let loggedSets = allSets.filter { $0.status == .logged }
            let total: Double = loggedSets.reduce(0) { $0 + $1.volumeKg }
            let display = WeightFormatter.format(total, unitSystem: appState.unitSystem)
            return BoxMetric(value: display, subtitle: "all time")
        case .muscleBalance:
            return BoxMetric(value: "\(muscleBalanceScore(sessions: activeSessions))%", subtitle: "volume spread")
        case .maxWeight:
            let allSetsForMax = activeSessions.flatMap { s in s.exercises.flatMap { e in e.sets } }
            let loggedWithWeight = allSetsForMax.filter { $0.status == .logged && $0.weight != nil }
            let heaviest = loggedWithWeight.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) })
            if let h = heaviest, let w = h.weight {
                let exName: String = activeSessions.compactMap { session -> String? in
                    for ex in session.exercises {
                        if ex.sets.contains(where: { $0.id == h.id }) { return ex.exerciseName }
                    }
                    return nil
                }.first ?? ""
                let wStr = WeightFormatter.format(w, unitSystem: appState.unitSystem)
                let sub = exName.isEmpty ? nil : exName
                return BoxMetric(value: wStr, subtitle: sub)
            }
            return BoxMetric(value: "—", subtitle: nil)
        }
    }

    private func consistencyPct(sessions: [SessionDTO], target: Int) -> Int {
        let cal = Calendar.current
        let now = Date()
        var totalPct: Double = 0
        var weeks = 0
        for weekOffset in 0..<4 {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let wkStart = cal.dateInterval(of: .weekOfYear, for: weekStart)?.start,
                  let wkEnd = cal.date(byAdding: .day, value: 7, to: wkStart) else { continue }
            let count = sessions.filter { $0.startedAt >= wkStart && $0.startedAt < wkEnd }.count
            totalPct += min(1.0, Double(count) / Double(target))
            weeks += 1
        }
        guard weeks > 0 else { return 0 }
        return min(100, Int((totalPct / Double(weeks)) * 100))
    }

    private func muscleBalanceScore(sessions: [SessionDTO]) -> Int {
        // Simplified: count how many distinct muscle group categories have any volume
        // Perfect balance = all main groups represented
        guard !sessions.isEmpty else { return 0 }
        let exercises = sessions.flatMap { $0.exercises }
        let names = Set(exercises.map { $0.exerciseName.lowercased() })
        let groups = ["chest", "back", "shoulder", "leg", "squat", "deadlift",
                      "press", "row", "curl", "tricep", "core", "hip"]
        var covered = 0
        for g in groups {
            if names.contains(where: { $0.contains(g) }) { covered += 1 }
        }
        return min(100, Int(Double(covered) / Double(groups.count) * 100))
    }
}

// MARK: - Analytics box enum

enum AnalyticsBox: String, Identifiable, CaseIterable {
    case consistency, totalWeight, muscleBalance, maxWeight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .consistency:   return "Consistency"
        case .totalWeight:   return "Total Weight"
        case .muscleBalance: return "Muscle Balance"
        case .maxWeight:     return "Max Weight"
        }
    }
}

// MARK: - Expanded detail view

private struct AnalyticsDetailView: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let box: AnalyticsBox

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailContent
                    }
                    .padding(18)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(box.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.ironiqOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailContent: some View {
        let activeSessions = historyVM.sessions.filter { !$0.isFromArchivedTemplate }
        switch box {
        case .consistency:
            consistencyDetail(sessions: activeSessions)
        case .totalWeight:
            totalWeightDetail(sessions: activeSessions)
        case .muscleBalance:
            muscleBalanceDetail(sessions: activeSessions)
        case .maxWeight:
            maxWeightDetail(sessions: activeSessions)
        }
    }

    // MARK: Consistency detail

    private func consistencyDetail(sessions: [SessionDTO]) -> some View {
        let data = weeklySessionCounts(sessions: sessions)
        let target = appState.sessionsPerWeekTarget
        let streak = currentStreak(sessions: sessions)
        let avg = data.isEmpty ? 0.0 : Double(data.map(\.count).reduce(0, +)) / Double(data.count)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                statPill("Streak", "\(streak) wks", Color.ironiqGreen)
                statPill("Avg/wk", String(format: "%.1f", avg), Color.ironiqOrange)
                statPill("Target", "\(target)/wk", .white.opacity(0.6))
            }

            if !data.isEmpty {
                Chart {
                    ForEach(data.suffix(12)) { point in
                        LineMark(x: .value("Week", point.weekLabel), y: .value("Sessions", point.count))
                            .foregroundStyle(Color.ironiqOrange)
                        PointMark(x: .value("Week", point.weekLabel), y: .value("Sessions", point.count))
                            .foregroundStyle(Color.ironiqOrange)
                    }
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(height: 180)
                .chartXAxis(.hidden)
                .foregroundStyle(.white)
            } else {
                emptyChartPlaceholder
            }
        }
    }

    private func currentStreak(sessions: [SessionDTO]) -> Int {
        let cal = Calendar.current
        var streak = 0
        var check = Date()
        while true {
            guard let wkStart = cal.dateInterval(of: .weekOfYear, for: check)?.start,
                  let wkEnd = cal.date(byAdding: .day, value: 7, to: wkStart) else { break }
            if sessions.contains(where: { $0.startedAt >= wkStart && $0.startedAt < wkEnd }) {
                streak += 1
                check = wkStart.addingTimeInterval(-1)
            } else { break }
        }
        return streak
    }

    private struct WeekPoint: Identifiable {
        let id = UUID(); let weekLabel: String; let count: Int
    }
    private func weeklySessionCounts(sessions: [SessionDTO]) -> [WeekPoint] {
        let cal = Calendar.current
        var grouped: [Date: Int] = [:]
        for s in sessions {
            let start = cal.dateInterval(of: .weekOfYear, for: s.startedAt)?.start ?? s.startedAt
            grouped[start, default: 0] += 1
        }
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return grouped.sorted { $0.key < $1.key }.map { WeekPoint(weekLabel: df.string(from: $0.key), count: $0.value) }
    }

    // MARK: Total weight detail

    private func totalWeightDetail(sessions: [SessionDTO]) -> some View {
        let byDate = cumulativeVolume(sessions: sessions)
        let allSets = sessions.flatMap { s in s.exercises.flatMap { e in e.sets } }
        let total: Double = allSets.filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg }
        return VStack(alignment: .leading, spacing: 16) {
            Text(WeightFormatter.format(total, unitSystem: appState.unitSystem))
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)
            if !byDate.isEmpty {
                Chart {
                    ForEach(byDate) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Volume", p.cumulative))
                            .foregroundStyle(Color.ironiqOrange)
                    }
                }
                .frame(height: 160)
                .chartXAxis(.hidden)
                .foregroundStyle(.white)
            } else { emptyChartPlaceholder }
        }
    }

    private struct VolPoint: Identifiable {
        let id = UUID(); let date: Date; let cumulative: Double
    }
    private func cumulativeVolume(sessions: [SessionDTO]) -> [VolPoint] {
        var cum: Double = 0
        return sessions.sorted { $0.startedAt < $1.startedAt }.map { s in
            cum += s.exercises.flatMap(\.sets).filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg }
            return VolPoint(date: s.startedAt, cumulative: cum)
        }
    }

    // MARK: Muscle balance detail

    private func muscleBalanceDetail(sessions: [SessionDTO]) -> some View {
        let groups = muscleGroupVolumes(sessions: sessions).sorted { $0.volume > $1.volume }
        let maxVol = groups.first?.volume ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            if groups.isEmpty {
                emptyChartPlaceholder
            } else {
                ForEach(groups, id: \.name) { g in
                    HStack {
                        Text(g.name.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(width: 100, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ironiqOrange)
                                .frame(width: geo.size.width * CGFloat(g.volume / maxVol))
                                .frame(height: 18)
                        }
                        .frame(height: 18)
                    }
                }
                if let dominant = groups.first, groups.count > 1, dominant.volume > groups[1].volume * 1.5 {
                    Text("\(dominant.name.capitalized) dominant — consider more variety")
                        .font(.caption)
                        .foregroundStyle(Color.ironiqOrange.opacity(0.8))
                        .padding(.top, 8)
                }
            }
        }
    }

    private struct GroupVolume { let name: String; let volume: Double }
    private func muscleGroupVolumes(sessions: [SessionDTO]) -> [GroupVolume] {
        let keywords: [(String, [String])] = [
            ("chest",     ["bench", "chest", "fly", "push up", "dip"]),
            ("back",      ["row", "pulldown", "pull up", "chin up", "deadlift"]),
            ("shoulders", ["shoulder", "press", "lateral", "front raise", "face pull"]),
            ("legs",      ["squat", "leg", "lunge", "hip thrust", "glute", "calf", "nordic"]),
            ("biceps",    ["curl", "bicep"]),
            ("triceps",   ["tricep", "skull", "pushdown"]),
            ("core",      ["plank", "crunch", "ab ", "rollout"])
        ]
        var volumes: [String: Double] = [:]
        for session in sessions {
            for ex in session.exercises {
                let name = ex.exerciseName.lowercased()
                let vol = ex.sets.filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg }
                for (group, kws) in keywords {
                    if kws.contains(where: { name.contains($0) }) {
                        volumes[group, default: 0] += vol
                        break
                    }
                }
            }
        }
        return volumes.map { GroupVolume(name: $0.key, volume: $0.value) }
    }

    // MARK: Max weight detail

    @State private var selectedExercise: String? = nil

    private func maxWeightDetail(sessions: [SessionDTO]) -> some View {
        let exerciseNames = Array(Set(sessions.flatMap { $0.exercises.map(\.exerciseName) })).sorted()
        let selected = selectedExercise ?? exerciseNames.first ?? ""
        let history = prHistory(sessions: sessions, exerciseName: selected)

        return VStack(alignment: .leading, spacing: 16) {
            if !exerciseNames.isEmpty {
                Picker("Exercise", selection: Binding(
                    get: { selected },
                    set: { selectedExercise = $0 }
                )) {
                    ForEach(exerciseNames, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.ironiqOrange)
            }
            if !history.isEmpty {
                Chart {
                    ForEach(history) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Weight", p.weight))
                            .foregroundStyle(Color.ironiqOrange)
                        PointMark(x: .value("Date", p.date), y: .value("Weight", p.weight))
                            .foregroundStyle(Color.ironiqOrange)
                    }
                }
                .frame(height: 160)
                .chartXAxis(.hidden)
                .foregroundStyle(.white)

                ForEach(history.sorted { $0.weight > $1.weight }.prefix(5)) { p in
                    HStack {
                        Text(p.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(WeightFormatter.format(p.weight, unitSystem: appState.unitSystem))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            } else { emptyChartPlaceholder }
        }
    }

    private struct PRPoint: Identifiable {
        let id = UUID(); let date: Date; let weight: Double
    }
    private func prHistory(sessions: [SessionDTO], exerciseName: String) -> [PRPoint] {
        sessions.sorted { $0.startedAt < $1.startedAt }.compactMap { session in
            guard let ex = session.exercises.first(where: { $0.exerciseName == exerciseName }) else { return nil }
            guard let maxW = ex.sets.filter({ $0.status == .logged }).compactMap(\.weight).max() else { return nil }
            return PRPoint(date: session.startedAt, weight: maxW)
        }
    }

    // MARK: Helpers

    private func statPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var emptyChartPlaceholder: some View {
        Text("No data yet. Complete some workouts to see analytics.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
}

#Preview {
    let appState = AppState()
    AnalyticsView()
        .environment(appState)
        .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: appState))
}
