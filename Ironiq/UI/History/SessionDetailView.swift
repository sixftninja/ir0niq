import SwiftUI

struct SessionDetailView: View {
    let session: SessionDTO

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(workoutTitle)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        metric("Duration", actualDuration.timerFormatted, "timer")
                        metric("Sets", "\(loggedSets.count)", "checkmark.circle")
                        metric("Volume", totalVolumeText, "scalemass")
                        metric("Best", bestResultText, "sparkline")
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color(white: 0.1))

            ForEach(session.exercises.sorted { $0.order < $1.order }) { exercise in
                Section(exercise.exerciseName) {
                    ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                        HStack {
                            Text("Set \(set.order + 1)")
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            if set.status == .logged {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(setResultText(set))
                                        .foregroundStyle(.white)
                                    if let rest = set.restDuration {
                                        Text("rest \(rest.timerFormatted)")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                }
                            } else {
                                Text(set.status.rawValue.capitalized)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .listRowBackground(Color(white: 0.1))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ironiqDark)
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).foregroundStyle(.white)
        }
        .font(.subheadline)
    }

    private var workoutTitle: String {
        session.exercises.isEmpty ? "Workout" : "\(session.exercises.count) Exercises"
    }

    private var actualDuration: TimeInterval {
        guard let endedAt = session.endedAt else { return 0 }
        return max(0, endedAt.timeIntervalSince(session.startedAt) - session.totalPauseDuration)
    }

    private var loggedSets: [SessionSetDTO] {
        session.exercises.flatMap(\.sets).filter { $0.status == .logged }
    }

    private var totalVolumeText: String {
        let total = loggedSets.reduce(0) { partial, set in
            partial + Double(set.reps ?? 0) * (set.weight ?? 0)
        }
        return total > 0 ? String(format: "%.0f kg", total) : "—"
    }

    private var bestResultText: String {
        if let duration = loggedSets.compactMap(\.durationSeconds).max() {
            return "\(Int(duration)) sec"
        }
        if let weight = loggedSets.compactMap(\.weight).max() {
            return String(format: "%.0f kg", weight)
        }
        if let reps = loggedSets.compactMap(\.reps).max() {
            return "\(reps) reps"
        }
        return "—"
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func setResultText(_ set: SessionSetDTO) -> String {
        let result: String
        if let duration = set.durationSeconds {
            result = "\(Int(duration)) sec"
        } else if let reps = set.reps {
            result = "\(reps) reps"
        } else {
            result = "Logged"
        }
        if let w = set.weight {
            return result + String(format: " @ %.0f kg", w)
        }
        return result
    }
}

extension SessionExerciseDTO: Hashable {
    public static func == (l: SessionExerciseDTO, r: SessionExerciseDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
extension SessionSetDTO: Hashable {
    public static func == (l: SessionSetDTO, r: SessionSetDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
