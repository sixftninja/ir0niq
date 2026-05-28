import SwiftUI

struct SessionSummaryView: View {
    @Environment(SessionViewModel.self) private var vm
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(\.dismiss) private var dismiss

    // Populated from the just-completed session
    @State private var summary: SessionSummary? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let s = summary {
                        // Duration
                        statCard(icon: "clock.fill", label: "Duration", value: s.duration.timerFormatted)

                        // Exercises
                        statCard(icon: "dumbbell.fill", label: "Exercises", value: "\(s.exerciseCount)")

                        // Sets
                        statCard(icon: "checkmark.circle.fill", label: "Sets Logged", value: "\(s.setsLogged)")

                        // Volume
                        statCard(icon: "chart.bar.fill", label: "Total Volume", value: "\(Int(s.totalVolumeKg)) kg")

                        // Exercise list
                        exerciseBreakdown(s)
                    } else {
                        ProgressView()
                            .tint(.forgeOrange)
                    }
                }
                .padding(16)
            }
            .background(Color.forgeDark)
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await vm.reset()
                            await historyVM.loadSessions()
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("session_done_button")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadSummary() }
    }

    @ViewBuilder
    private func statCard(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.forgeOrange)
                .frame(width: 28)
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.body).bold()
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func exerciseBreakdown(_ s: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Breakdown")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(s.exercises, id: \.name) { ex in
                HStack {
                    Text(ex.name)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(ex.setsLogged) sets")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func loadSummary() async {
        // Pull summary from the just-completed session via historyVM
        await historyVM.loadSessions()
        guard let session = historyVM.sessions.first else { return }
        summary = SessionSummary(from: session)
    }
}

// MARK: - Summary model

private struct SessionSummary {
    let duration: TimeInterval
    let exerciseCount: Int
    let setsLogged: Int
    let totalVolumeKg: Double
    let exercises: [ExSummary]

    struct ExSummary { let name: String; let setsLogged: Int }

    init(from dto: SessionDTO) {
        let end = dto.endedAt ?? Date()
        duration = end.timeIntervalSince(dto.startedAt) - dto.totalPauseDuration
        exerciseCount = dto.exercises.count
        let logged = dto.exercises.flatMap(\.sets).filter { $0.status == .logged }
        setsLogged = logged.count
        totalVolumeKg = logged.reduce(0) { $0 + Double(($1.reps ?? 0)) * ($1.weight ?? 0) }
        exercises = dto.exercises.map {
            ExSummary(name: $0.exerciseName, setsLogged: $0.sets.filter { $0.status == .logged }.count)
        }
    }
}

#Preview {
    SessionSummaryView()
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(HistoryViewModel(
            sessionRepo: PreviewRepositories.session,
            appState: AppState()
        ))
}
