import SwiftUI

struct HomeView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(HistoryViewModel.self) private var historyVM
    @State private var showTemplateEditor = false
    @State private var templateToEdit: TemplateDTO?
    @State private var selectedTemplate: TemplateDTO?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    savedWorkoutsSection

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.ironiqDark)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SessionDTO.self) { session in
                SessionDetailView(session: session)
            }
        }
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorView()
        }
        .sheet(item: $templateToEdit) { template in
            TemplateEditorView(existingTemplate: template)
        }
        .confirmationDialog(
            selectedTemplate?.name ?? "Template",
            isPresented: Binding(
                get: { selectedTemplate != nil },
                set: { if !$0 { selectedTemplate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Start") {
                guard let template = selectedTemplate else { return }
                selectedTemplate = nil
                Task {
                    _ = await sessionVM.startTemplateSession(template.id)
                }
            }
            Button("Edit") {
                templateToEdit = selectedTemplate
                selectedTemplate = nil
            }
            Button("Cancel", role: .cancel) {
                selectedTemplate = nil
            }
        }
    }

    private var savedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showTemplateEditor = true
            } label: {
                HStack {
                    Text("New Template")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.ironiqOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("new_template_button")

            VStack(alignment: .leading, spacing: 10) {
                Text("Created Templates")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                if templateVM.templates.isEmpty {
                    Text("Created templates are saved here. Create a template to get started.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(templateVM.templates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            SavedWorkoutRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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

// MARK: - Saved workout row

private struct SavedWorkoutRow: View {
    let template: TemplateDTO

    var body: some View {
        HStack(spacing: 12) {
            Text(template.name)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text("\(template.exercises.count) exercises")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 86, alignment: .trailing)
            Text(template.targetCompletionTime.timerFormatted)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.ironiqOrange)
                .frame(width: 54, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(15)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                Text(sessionSummary)
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

    private var sessionSummary: String {
        let sets = session.exercises.flatMap(\.sets).filter { $0.status == .logged }
        let duration = sets.compactMap(\.durationSeconds).reduce(0, +)
        let durationText = duration > 0 ? " · \(Int(duration)) sec logged" : ""
        return "\(session.exercises.count) exercises · \(sets.count) sets logged\(durationText)"
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
