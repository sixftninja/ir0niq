import SwiftUI

struct TemplateListView: View {
    @Environment(TemplateViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(StoreKitService.self) private var storeKit
    @State private var showEditor = false
    @State private var showProGate = false
    @State private var purchaseErrorMessage = ""
    @State private var showPurchaseError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button { handleNew() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Create Template")
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                                Text("Name it, add exercises, set rest targets.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color.ironiqOrange)
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("new_template_button")

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    if vm.templates.isEmpty {
                        ContentUnavailableView(
                            "No Templates",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Create your first saved workout.")
                        )
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(vm.templates) { template in
                                NavigationLink(value: template) {
                                    templateRow(template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 90)
            }
            .background(Color.ironiqDark)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TemplateDTO.self) { template in
                TemplateDetailView(template: template)
            }
            .sheet(isPresented: $showEditor) {
                TemplateEditorView()
            }
            .sheet(isPresented: $showProGate) {
                proGateSheet
            }
            .alert("Purchase Failed", isPresented: $showPurchaseError) {
                Button("OK") {}
            } message: {
                Text(purchaseErrorMessage)
            }
            
        }
    }

    @ViewBuilder
    private func templateRow(_ template: TemplateDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(template.exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(targetTime(for: template))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.ironiqOrange)
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(15)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func targetTime(for template: TemplateDTO) -> String {
        let rest = template.exercises.flatMap(\.sets).compactMap(\.restDuration).reduce(0, +)
        return rest > 0 ? rest.timerFormatted : "No target"
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
            Color.ironiqDark.ignoresSafeArea()
            ProGateView(feature: "More than \(AppState.freeTemplateLimit) templates") {
                Task {
                    do {
                        if try await storeKit.purchase(appState: appState) {
                            showProGate = false
                        }
                    } catch {
                        purchaseErrorMessage = error.localizedDescription
                        showPurchaseError = true
                    }
                }
            }
        }
        
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
        .environment(StoreKitService.shared)
}
