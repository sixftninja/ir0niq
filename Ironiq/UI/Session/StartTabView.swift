import SwiftUI

// MARK: - Start tab: Workout sub-tab + Templates sub-tab

struct StartTabView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(TemplateViewModel.self) private var templateVM
    @Binding var showWorkoutDashboard: Bool
    @Binding var showExercisePicker: Bool
    @State private var selectedSubTab: StartSubTab = .workout
    @State private var pendingExerciseToAdd: ExerciseDTO?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                VStack(spacing: 0) {
                    subTabPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    switch selectedSubTab {
                    case .workout: WorkoutSubtabView(startSession: startSession)
                    case .templates: TemplatesSubtabView()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showExercisePicker) {
            NavigationStack {
                Group {
                    if let exercise = pendingExerciseToAdd {
                        AddExerciseToWorkoutView(exercise: exercise) { sets in
                            Task {
                                await sessionVM.addUnplannedExercise(
                                    exerciseId: exercise.id,
                                    exerciseName: exercise.name,
                                    sets: sets,
                                    defaultLoggingType: exercise.defaultLoggingType
                                )
                                pendingExerciseToAdd = nil
                                showExercisePicker = false
                            }
                        } onBack: {
                            pendingExerciseToAdd = nil
                        }
                    } else {
                        ExercisePickerView { exercise in pendingExerciseToAdd = exercise }
                    }
                }
            }
        }
        .onChange(of: showExercisePicker) { _, isPresented in
            if !isPresented { pendingExerciseToAdd = nil }
        }
        .task {
            if templateVM.templates.isEmpty { await templateVM.loadAll() }
        }
    }

    private var subTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(StartSubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSubTab = tab }
                } label: {
                    Text(tab.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedSubTab == tab ? .black : .white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selectedSubTab == tab ? Color.ironiqOrange : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityIdentifier("start_subtab_\(tab.label.lowercased())")
            }
        }
    }

    private func startSession(templateId: UUID?) async {
        let started: Bool
        if let templateId {
            started = await sessionVM.startTemplateSession(templateId)
        } else {
            started = await sessionVM.startAdHocSession()
        }
        if started { showWorkoutDashboard = true }
    }
}

private enum StartSubTab: CaseIterable {
    case workout, templates
    var label: String { self == .workout ? "Workout" : "Templates" }
}

// MARK: - Workout sub-tab

private struct WorkoutSubtabView: View {
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(HistoryViewModel.self) private var historyVM
    let startSession: (UUID?) async -> Void
    @State private var expandedTemplateId: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Quick Start pinned at top
                Button {
                    Task { await startSession(nil) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Start")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Start a blank session")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.ironiqOrange)
                    }
                    .padding(15)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.ironiqOrange.opacity(0.45), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quick_start_button")

                if templateVM.templates.isEmpty {
                    Text("Create templates in the Templates tab to see them here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(templateVM.templates) { template in
                        templateWorkoutRow(template)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func templateWorkoutRow(_ template: TemplateDTO) -> some View {
        let isExpanded = expandedTemplateId == template.id
        VStack(alignment: .leading, spacing: 0) {
            // Row header — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedTemplateId = isExpanded ? nil : template.id
                }
            } label: {
                HStack(spacing: 12) {
                    Text(template.name)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(template.exercises.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(template.targetCompletionTime.timerFormatted)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.ironiqOrange)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(15)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout_template_row")

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Last workout card
                    lastWorkoutCard(for: template)

                    // Exercise list
                    ForEach(template.exercises.sorted { $0.order < $1.order }) { exercise in
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(exercise.sets.count) sets")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }

                    Button {
                        Task { await startSession(template.id) }
                    } label: {
                        Text("Begin Workout")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.ironiqOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("begin_workout_button")
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func lastWorkoutCard(for template: TemplateDTO) -> some View {
        let lastSession = historyVM.sessions.first { $0.templateId == template.id }
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            if let last = lastSession {
                let volume = last.exercises.flatMap(\.sets)
                    .filter { $0.status == .logged }
                    .reduce(0) { $0 + $1.volumeKg }
                let planned = last.exercises.flatMap(\.sets).count
                let logged = last.exercises.flatMap(\.sets).filter { $0.status == .logged }.count
                let pct = planned > 0 ? Int(Double(logged) / Double(planned) * 100) : 0
                Text("\(last.startedAt.formatted(date: .abbreviated, time: .omitted))  ·  \(String(format: "%.0f", volume)) kg  ·  \(pct)%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("First session")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Templates sub-tab

private struct TemplatesSubtabView: View {
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(AppState.self) private var appState
    @State private var showTemplateEditor = false
    @State private var templateToEdit: TemplateDTO?
    @State private var templateToDelete: TemplateDTO?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Templates")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.top, 4)

                Button {
                    showTemplateEditor = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.ironiqOrange)
                        Text("New Template")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.ironiqOrange)
                        Spacer()
                    }
                    .padding(15)
                    .background(Color.ironiqOrange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.ironiqOrange.opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("new_template_button")

                if templateVM.templates.isEmpty {
                    Text("Create a template to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(templateVM.templates) { template in
                        templateManageRow(template)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showTemplateEditor) { TemplateEditorView() }
        .sheet(item: $templateToEdit) { t in TemplateEditorView(existingTemplate: t) }
        .confirmationDialog(
            "Delete \"\(templateToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { templateToDelete != nil }, set: { if !$0 { templateToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let t = templateToDelete {
                    Task { await templateVM.deleteTemplate(t.id) }
                }
                templateToDelete = nil
            }
            Button("Cancel", role: .cancel) { templateToDelete = nil }
        } message: {
            Text("Sessions from this template will remain in History.")
        }
    }

    private func templateManageRow(_ template: TemplateDTO) -> some View {
        HStack(spacing: 12) {
            Text(template.name)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(template.exercises.count) ex")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(template.targetCompletionTime.timerFormatted)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.ironiqOrange.opacity(0.85))
        }
        .padding(15)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                templateToDelete = template
            } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                templateToEdit = template
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.ironiqOrange)
        }
        .accessibilityIdentifier("templates_manage_row")
    }
}

// MARK: - Add Exercise to Active Workout (re-exported for StartTabView)
// AddExerciseToWorkoutView lives in StartView.swift — no re-declaration needed.

#Preview {
    let appState = AppState()
    StartTabView(showWorkoutDashboard: .constant(false), showExercisePicker: .constant(false))
        .environment(appState)
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
        .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: appState))
}
