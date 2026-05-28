import SwiftUI

struct HomeView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(HistoryViewModel.self) private var historyVM
    @State private var showTemplatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick start
                    quickStartSection

                    // Recent sessions
                    if !historyVM.sessions.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.forgeDark)
            .navigationTitle("Forge")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet { templateId in
                showTemplatePicker = false
                Task {
                    await sessionVM.selectTemplate(templateId)
                    await sessionVM.startSession()
                }
            }
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Workout")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Button {
                showTemplatePicker = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Choose Template")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.forgeOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("start_workout_button")

            Button {
                Task { await sessionVM.startAdHocSession() }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Ad-hoc Session")
                        .font(.headline)
                }
                .foregroundStyle(Color.forgeOrange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.forgeOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.forgeOrange.opacity(0.3), lineWidth: 1)
                )
            }
            .accessibilityIdentifier("adhoc_session_button")
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            ForEach(historyVM.sessions.prefix(3)) { session in
                NavigationLink(value: session) {
                    SessionRowView(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Template picker sheet

private struct TemplatePickerSheet: View {
    @Environment(TemplateViewModel.self) private var templateVM
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if templateVM.templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a template to get started.")
                    )
                } else {
                    List(templateVM.templates) { template in
                        Button(template.name) { onSelect(template.id) }
                            .foregroundStyle(.white)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.forgeDark)
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Session row

struct SessionRowView: View {
    let session: SessionDTO

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.body).bold()
                    .foregroundStyle(.white)
                Text("\(session.exercises.count) exercises · \(session.exercises.flatMap(\.sets).filter { $0.status == .logged }.count) sets logged")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension SessionDTO: Hashable {
    public static func == (lhs: SessionDTO, rhs: SessionDTO) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    HomeView()
        .environment(AppState())
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
        .environment(HistoryViewModel(
            sessionRepo: PreviewRepositories.session,
            appState: AppState()
        ))
}
