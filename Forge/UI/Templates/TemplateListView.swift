import SwiftUI

struct TemplateListView: View {
    @Environment(TemplateViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showEditor = false
    @State private var showProGate = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Tap + to create your first template.")
                    )
                    .background(Color.forgeDark)
                } else {
                    List {
                        ForEach(vm.templates) { template in
                            NavigationLink(value: template) {
                                templateRow(template)
                            }
                            .listRowBackground(Color(white: 0.1))
                        }
                        .onDelete { indexSet in
                            Task {
                                for i in indexSet {
                                    await vm.deleteTemplate(vm.templates[i].id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.forgeDark)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { handleNew() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("new_template_button")
                }
            }
            .navigationDestination(for: TemplateDTO.self) { template in
                TemplateDetailView(template: template)
            }
            .sheet(isPresented: $showEditor) {
                TemplateEditorView()
            }
            .sheet(isPresented: $showProGate) {
                proGateSheet
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func templateRow(_ template: TemplateDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body).bold()
                .foregroundStyle(.white)
            Text("\(template.exercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private func handleNew() {
        if vm.canCreateTemplate(appState: appState) {
            showEditor = true
        } else {
            showProGate = true
        }
    }

    private var proGateSheet: some View {
        ZStack {
            Color.forgeDark.ignoresSafeArea()
            ProGateView(feature: "More than \(AppState.freeTemplateLimit) templates") {
                appState.isProUser = true
                showProGate = false
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension TemplateDTO: Hashable {
    public static func == (lhs: TemplateDTO, rhs: TemplateDTO) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    TemplateListView()
        .environment(AppState())
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
}
