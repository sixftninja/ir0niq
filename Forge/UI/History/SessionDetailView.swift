import SwiftUI

struct SessionDetailView: View {
    let session: SessionDTO

    var body: some View {
        List {
            Section("Overview") {
                row("Date", session.startedAt.formatted(date: .long, time: .shortened))
                row("Status", session.status.rawValue.capitalized)
                if let endedAt = session.endedAt {
                    let dur = endedAt.timeIntervalSince(session.startedAt) - session.totalPauseDuration
                    row("Duration", dur.timerFormatted)
                }
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
                                Group {
                                    if let reps = set.reps { Text("\(reps) reps") }
                                    if let w = set.weight { Text(String(format: "@ %.0f kg", w)) }
                                }
                                .foregroundStyle(.white)
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
        .background(Color.forgeDark)
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
}

extension SessionExerciseDTO: Hashable {
    public static func == (l: SessionExerciseDTO, r: SessionExerciseDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
extension SessionSetDTO: Hashable {
    public static func == (l: SessionSetDTO, r: SessionSetDTO) -> Bool { l.id == r.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
