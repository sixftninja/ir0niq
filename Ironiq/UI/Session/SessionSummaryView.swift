import SwiftUI

struct SessionSummaryView: View {
    @Environment(SessionViewModel.self) private var vm
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var summary: WorkoutExportSession? = nil
    @State private var sourceSession: SessionDTO? = nil
    @State private var animate = false
    @State private var showMissedSetEditor = false
    @State private var showTemplatePrompt = false
    @State private var showTemplateNameSheet = false
    @State private var templateName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        if let summary {
                            completionHero(summary)
                            metricGrid(summary)
                        } else {
                            ProgressView()
                                .tint(.ironiqOrange)
                                .padding(.top, 80)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 108)
                }
            }
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                summaryActions
            }
            .sheet(isPresented: $showMissedSetEditor) {
                if let sourceSession {
                    MissedSetEditorView(session: sourceSession) {
                        Task { await loadSummary() }
                    }
                }
            }
            .confirmationDialog("Save as template?", isPresented: $showTemplatePrompt, titleVisibility: .visible) {
                Button("Yes") {
                    templateName = defaultTemplateName
                    showTemplateNameSheet = true
                }
                Button("No") {
                    Task { await finishSummary() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save this workout as a reusable template, or keep it in history only?")
            }
            .sheet(isPresented: $showTemplateNameSheet) {
                saveTemplateSheet
            }
        }
        .task { await loadSummary() }
    }

    private func completionHero(_ summary: WorkoutExportSession) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 142, height: 142)
                Circle()
                    .trim(from: 0, to: animate ? completionRatio(summary) : 0)
                    .stroke(Color.ironiqGreen, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 142, height: 142)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 74, height: 74)
                    .background(Color.ironiqGreen)
                    .clipShape(Circle())
                    .scaleEffect(animate ? 1 : 0.72)
                    .opacity(animate ? 1 : 0)
            }

            VStack(spacing: 5) {
                Text("Session complete")
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                Text(summary.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.top, 18)
        .accessibilityIdentifier("session_summary_hero")
    }

    private func metricGrid(_ summary: WorkoutExportSession) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            metric("Duration", summary.durationSeconds.timerFormatted, "timer")
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.18), value: animate)
            metric("Exercises", "\(summary.exerciseCount)", "figure.strengthtraining.traditional")
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.26), value: animate)
            metric("Volume", volumeText(summary.totalVolumeKg), "scalemass")
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.34), value: animate)
            metric("Peak HR", heartRateText(summary.peakHeartRateBPM), "heart.fill", accent: Color.ironiqRed)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.42), value: animate)
        }
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 18)
    }

    private func metric(_ title: String, _ value: String, _ icon: String, accent: Color = Color.ironiqOrange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func exerciseBreakdown(_ summary: WorkoutExportSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Breakdown")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            ForEach(summary.exercises, id: \.name) { exercise in
                HStack(spacing: 12) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(exercise.setsLogged) sets | \(exercise.totalRestSeconds.timerFormatted) rest")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exportPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "curlybraces.square")
                .font(.title3)
                .foregroundStyle(Color.ironiqOrange)
            VStack(alignment: .leading, spacing: 3) {
                Text("AI-ready history")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("This summary now uses the same structured model planned for JSON and Markdown export.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }


    private var summaryActions: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                Task { await discardSummary() }
            } label: {
                Text("Discard")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.ironiqRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("discard_session_button")

            Button {
                showMissedSetEditor = true
            } label: {
                Text("Edit")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(sourceSession == nil)
            .accessibilityIdentifier("edit_session_button")

            Button {
                Task { await saveSummary() }
            } label: {
                Text("Save")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.ironiqOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityIdentifier("save_session_button")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.ironiqDark)
    }

    private var saveTemplateSheet: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("Save as Template")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                    TextField("Template name", text: $templateName)
                        .textInputAutocapitalization(.words)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    IroniqButton("Save Template") {
                        Task { await createTemplateAndFinish() }
                    }
                    .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    Spacer()
                }
                .padding(18)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTemplateNameSheet = false }
                }
            }
        }
    }

    private func saveSummary() async {
        await templateVM.loadAll()
        if canOfferTemplateSave {
            showTemplatePrompt = true
        } else {
            await finishSummary()
        }
    }

    private func finishSummary() async {
        await vm.reset()
        await historyVM.loadSessions()
        dismiss()
    }

    private var canOfferTemplateSave: Bool {
        guard let sourceSession, sourceSession.templateId == nil, !sourceSession.exercises.isEmpty else { return false }
        return templateVM.canCreateTemplate(appState: appState)
    }

    private var defaultTemplateName: String {
        guard let sourceSession else { return "New Template" }
        return "Workout \(sourceSession.startedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func createTemplateAndFinish() async {
        guard let sourceSession else { return }
        let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await templateVM.createTemplate(
                name: trimmed,
                exercises: templateInputs(from: sourceSession)
            )
            showTemplateNameSheet = false
            await finishSummary()
        } catch {
            templateVM.alertMessage = error.localizedDescription
            templateVM.showAlert = true
        }
    }

    private func templateInputs(from session: SessionDTO) -> [CreateTemplateExerciseInput] {
        session.exercises.sorted { $0.order < $1.order }.map { exercise in
            let sets = exercise.sets.sorted { $0.order < $1.order }.map { set in
                CreateTemplateSetInput(
                    targetReps: set.reps ?? (set.durationSeconds == nil ? 10 : nil),
                    targetWeight: set.weight,
                    targetDuration: set.durationSeconds,
                    restDuration: set.restDuration ?? 30
                )
            }
            return CreateTemplateExerciseInput(exerciseId: exercise.exerciseId, sets: sets.isEmpty ? [CreateTemplateSetInput(targetReps: 10, restDuration: 30)] : sets)
        }
    }

    private func discardSummary() async {
        if let id = vm.completedSessionId {
            await historyVM.deleteSession(id)
        }
        await vm.reset()
        await historyVM.loadSessions()
        dismiss()
    }

    private func completionRatio(_ summary: WorkoutExportSession) -> CGFloat {
        guard summary.exerciseCount > 0 else { return 1 }
        let completedExercises = summary.exercises.filter { $0.setsLogged > 0 }.count
        return CGFloat(max(0.18, min(1, Double(completedExercises) / Double(summary.exerciseCount))))
    }

    private func volumeText(_ kg: Double) -> String {
        kg > 0 ? WeightFormatter.format(kg, unitSystem: appState.unitSystem) : "Unavailable"
    }

    private func heartRateText(_ bpm: Double?) -> String {
        guard let bpm else { return "Unavailable" }
        return "\(Int(bpm.rounded())) bpm"
    }

    private func loadSummary() async {
        animate = false
        await historyVM.loadSessions()
        guard let completedId = vm.completedSessionId,
              let session = historyVM.sessions.first(where: { $0.id == completedId }) ?? historyVM.sessions.first else { return }
        sourceSession = session
        summary = WorkoutExportSession(from: session)
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
            animate = true
        }
    }
}


private struct MissedSetEditorView: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: SessionDTO
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                List {
                    ForEach(session.exercises.sorted { $0.order < $1.order }) { exercise in
                        Section(exercise.exerciseName) {
                            ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                                if set.status == .logged {
                                    lockedSetRow(set)
                                } else {
                                    MissedSetRow(exerciseName: exercise.exerciseName, set: set) {
                                        onSaved()
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func lockedSetRow(_ set: SessionSetDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set \(set.order + 1)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(loggedSetText(set))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(.white.opacity(0.38))
        }
    }

    private func loggedSetText(_ set: SessionSetDTO) -> String {
        let result = set.reps.map { "\($0) reps" } ?? set.durationSeconds.map { "\(Int($0)) sec" } ?? "Logged"
        let weight = set.weight.map { " | \(WeightFormatter.format($0, unitSystem: appState.unitSystem))" } ?? ""
        return result + weight
    }
}

private struct MissedSetRow: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(AppState.self) private var appState
    let exerciseName: String
    let set: SessionSetDTO
    let onSaved: () -> Void
    @State private var loggingType: SetLoggingType = .reps
    @State private var repsText = ""
    @State private var durationText = ""
    @State private var weightText = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(set.order + 1)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Incomplete")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.ironiqOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.ironiqOrange.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
            }

            Picker("Type", selection: $loggingType) {
                ForEach(SetLoggingType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                TextField(loggingType == .reps ? "10" : "30", text: loggingType == .reps ? $repsText : $durationText)
                    .keyboardType(.numberPad)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: repsText) { _, newValue in repsText = newValue.filter(\.isNumber) }
                    .onChange(of: durationText) { _, newValue in durationText = newValue.filter(\.isNumber) }
                TextField("Weight (\(WeightFormatter.unitLabel(appState.unitSystem)))", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                Task { await save() }
            } label: {
                Text("Log Missed Set")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ironiqOrange)
                    .clipShape(Capsule())
            }
            .disabled(isSaving)
            .opacity(isSaving ? 0.45 : 1)
        }
        .padding(.vertical, 6)
        .onAppear {
            if set.durationSeconds != nil { loggingType = .duration }
        }
    }

    private func save() async {
        isSaving = true
        let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")).map { WeightFormatter.toKg($0, unitSystem: appState.unitSystem) }
        let reps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 10
        let duration = Double(durationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 30
        await historyVM.updateMissedSet(
            setId: set.id,
            reps: loggingType == .reps ? reps : nil,
            durationSeconds: loggingType == .duration ? duration : nil,
            weight: weight
        )
        isSaving = false
        onSaved()
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
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
        .environment(AppState())
}
