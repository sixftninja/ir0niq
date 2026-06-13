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
                            endMetricGrid(summary)
                            encouragingText(summary)
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

    private func endMetricGrid(_ summary: WorkoutExportSession) -> some View {
        let lastSession = historyVM.sessions.first {
            guard let src = sourceSession else { return false }
            return $0.templateId == src.templateId && $0.id != src.id
        }
        let lastVolume = lastSession.map { s in
            s.exercises.flatMap(\.sets).filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg }
        }
        let volumeTrend: String? = lastVolume.map { lv in
            if summary.totalVolumeKg > lv { return "↑" }
            if summary.totalVolumeKg < lv { return "↓" }
            return "→"
        }
        let volumeTrendColor: Color = {
            guard let t = volumeTrend else { return .white }
            if t == "↑" { return .ironiqGreen }
            if t == "↓" { return .ironiqRed }
            return .white.opacity(0.55)
        }()

        let allSets = (sourceSession?.exercises ?? []).flatMap(\.sets)
        let plannedSets = allSets.count
        let loggedSets = allSets.filter { $0.status == .logged }.count
        let completionPct = plannedSets > 0 ? Int(Double(loggedSets) / Double(plannedSets) * 100) : 100

        let bestSet = (sourceSession?.exercises ?? []).flatMap(\.sets)
            .filter { $0.status == .logged && $0.weight != nil }
            .max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) })
        let bestLiftName = bestSet.flatMap { s in
            sourceSession?.exercises.first(where: { ex in ex.sets.contains(where: { $0.id == s.id }) })?.exerciseName
        }
        let bestLiftText: String = {
            guard let s = bestSet, let w = s.weight else { return "—" }
            let repsStr = s.reps.map { " × \($0) reps" } ?? ""
            let name = bestLiftName.map { "\($0) — " } ?? ""
            return "\(name)\(WeightFormatter.format(w, unitSystem: appState.unitSystem))\(repsStr)"
        }()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            endMetric("Volume", volumeText(summary.totalVolumeKg), "scalemass",
                      badge: volumeTrend, badgeColor: volumeTrendColor)
            endMetric("Best Lift", bestLiftText, "sparkline")
            endMetric("Completion", "\(completionPct)%", "checkmark.circle.fill")
            endMetric("Duration", summary.durationSeconds.timerFormatted, "timer")
        }
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 18)
        .accessibilityIdentifier("session_summary_metrics")
    }

    private func endMetric(_ title: String, _ value: String, _ icon: String,
                           badge: String? = nil, badgeColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ironiqOrange.opacity(0.9))
            HStack(spacing: 4) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let badge {
                    Text(badge)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(badgeColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func encouragingText(_ summary: WorkoutExportSession) -> some View {
        Text(encouragingLine(summary))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .opacity(animate ? 1 : 0)
    }

    private func encouragingLine(_ summary: WorkoutExportSession) -> String {
        let allSets = (sourceSession?.exercises ?? []).flatMap(\.sets)
        let planned = allSets.count
        let logged = allSets.filter { $0.status == .logged }.count
        let allComplete = planned > 0 && logged == planned

        let lastSession = historyVM.sessions.first {
            guard let src = sourceSession else { return false }
            return $0.templateId == src.templateId && $0.id != src.id
        }

        if historyVM.sessions.filter({ $0.templateId == sourceSession?.templateId }).count <= 1 {
            return "First one's always the hardest. Well done."
        }

        if let lv = lastSession.map({ s in
            s.exercises.flatMap(\.sets).filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg }
        }), summary.totalVolumeKg > lv {
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86400)
            let recentBest = historyVM.sessions
                .filter { ($0.startedAt > thirtyDaysAgo) && ($0.id != sourceSession?.id) }
                .map { s in s.exercises.flatMap(\.sets).filter { $0.status == .logged }.reduce(0) { $0 + $1.volumeKg } }
                .max() ?? 0
            if summary.totalVolumeKg > recentBest {
                return "Strongest session this month."
            }
            return "More volume than last time."
        }

        if allComplete { return "Perfect execution." }

        if let lastDur = lastSession?.actualDurationSeconds, summary.durationSeconds < lastDur {
            return "Done in record time."
        }

        return "Good work. See you next time."
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
