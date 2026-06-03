import SwiftUI

struct StartView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(TemplateViewModel.self) private var templateVM
    @Binding var showWorkoutDashboard: Bool
    @Binding var showLogOnDashboardOpen: Bool
    @Binding var showExercisePicker: Bool
    @State private var showEndConfirm = false
    @State private var pendingExerciseToAdd: ExerciseDTO?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ironiqDark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if sessionVM.isSessionActive {
                            activeWorkoutSurface
                        } else {
                            idleStartSurface
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle(sessionVM.isSessionActive ? "" : "Start")
            .navigationBarTitleDisplayMode(sessionVM.isSessionActive ? .inline : .large)
            .toolbar(sessionVM.isSessionActive ? .hidden : .visible, for: .navigationBar)
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
                        ExercisePickerView { exercise in
                            pendingExerciseToAdd = exercise
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { activeWorkoutMiniBar }
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Workout", role: .destructive) {
                Task {
                    _ = await sessionVM.endSession()
                    await sessionVM.confirmEnd()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: showExercisePicker) { _, isPresented in
            if !isPresented {
                pendingExerciseToAdd = nil
            }
        }
    }

    private var idleStartSurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Workout")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)

            startChoice(title: "New", icon: "plus.circle.fill") {
                Task {
                    if sessionVM.isSessionActive {
                        showWorkoutDashboard = true
                        return
                    }
                    let started = await sessionVM.startAdHocSession()
                    if started { showWorkoutDashboard = true }
                }
            }
            .accessibilityIdentifier("new_workout_button")

            VStack(alignment: .leading, spacing: 10) {
                Text("Templates")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))

                if templateVM.templates.isEmpty {
                    Text("Created templates are saved here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    ForEach(templateVM.templates) { template in
                        Button {
                            Task {
                                let started = await sessionVM.startTemplateSession(template.id)
                                if started { showWorkoutDashboard = true }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(template.name)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(template.exercises.count)")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.62))
                                    .frame(width: 34, alignment: .trailing)
                                Text(template.targetCompletionTime.timerFormatted)
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.62))
                                    .frame(width: 62, alignment: .trailing)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.065))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("start_template_row")
                    }
                }
            }
        }
        .task {
            if templateVM.templates.isEmpty || templateVM.exercises.isEmpty {
                await templateVM.loadAll()
            }
        }
    }

    private var activeWorkoutSurface: some View {
        WorkoutSessionView()
    }

    private func startChoice(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Color.ironiqOrange)
                    .clipShape(Circle())

                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ironiqOrange.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.ironiqOrange.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    private var activeWorkoutMiniBar: some View {
        HStack(spacing: 16) {
            Text(workoutName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Label(sessionVM.sessionElapsed.timerFormatted, systemImage: "timer")
            Label("\(completedExercises)/\(sessionVM.exercises.count)", systemImage: "checkmark.circle")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.ironiqDark)
    }

    private var workoutName: String {
        sessionVM.workoutName
    }

    private var completedExercises: Int {
        sessionVM.exercises.filter { $0.status == .complete || $0.status == .notPerformed }.count
    }

    private var needsSetLogging: Bool {
        guard let set = sessionVM.currentSet else { return false }
        if case .resting = set.lifecycleState { return true }
        if case .awaitingInput = set.lifecycleState { return true }
        return false
    }
}

// MARK: - Workout Session View

private struct WorkoutSessionView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(AppState.self) private var appState
    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            workoutNameHeader
            summaryRow
            if sessionVM.exercises.isEmpty {
                trueEmptyState
            } else {
                exerciseList
            }
        }
    }

    // MARK: - Renamable workout title

    private var workoutNameHeader: some View {
        Group {
            if isEditingName {
                TextField("Workout name", text: $editedName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .onSubmit { commitRename() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { commitRename() }
                                .foregroundStyle(Color.ironiqOrange)
                        }
                    }
            } else {
                Text(sessionVM.workoutName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .onTapGesture {
                        editedName = sessionVM.workoutName
                        isEditingName = true
                        nameFocused = true
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func commitRename() {
        isEditingName = false
        nameFocused = false
        Task { await sessionVM.renameWorkout(editedName) }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 6) {
            Text("\(loggedSetCount) of \(totalSetCount) sets logged")
            Text("·")
            Text("\(sessionVM.exercises.count) exercises")
            Text("·")
            Text(sessionVM.sessionElapsed.timerFormatted)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.55))
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("workout_session_summary")
    }

    // MARK: - Empty state (no exercises added)

    private var trueEmptyState: some View {
        Text("Add an exercise from the workout dashboard to begin")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(sessionVM.exercises.enumerated()), id: \.element.sessionExerciseId) { _, exercise in
                exerciseSection(exercise)
            }
        }
    }

    private func exerciseSection(_ exercise: ActiveSessionContext.ExerciseContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise header
            HStack {
                Text(exercise.exerciseName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                completionDot(for: exercise)
            }

            // Set rows
            VStack(spacing: 6) {
                ForEach(Array(exercise.setContexts.enumerated()), id: \.element.sessionSetId) { index, set in
                    setRow(set: set, index: index, exercise: exercise)
                }
            }
        }
    }

    private func setRow(
        set: ActiveSessionContext.ExerciseContext.SetContext,
        index: Int,
        exercise: ActiveSessionContext.ExerciseContext
    ) -> some View {
        let isLogged: Bool
        if case .logged = set.lifecycleState { isLogged = true } else { isLogged = false }
        let isSkipped = set.lifecycleState == .notPerformed

        return HStack(spacing: 8) {
            Text("Set \(index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(isLogged ? 0.45 : 0.2))
                .frame(width: 42, alignment: .leading)

            Text(setDisplayText(set: set, exercise: exercise))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(isLogged ? 1.0 : (isSkipped ? 0.3 : 0.22)))

            Spacer()

            if isLogged {
                Circle()
                    .fill(Color.ironiqGreen.opacity(0.75))
                    .frame(width: 7, height: 7)
            } else if isSkipped {
                Image(systemName: "minus")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func setDisplayText(
        set: ActiveSessionContext.ExerciseContext.SetContext,
        exercise: ActiveSessionContext.ExerciseContext
    ) -> String {
        switch set.lifecycleState {
        case .logged(let reps, let durationSeconds, let weight):
            let valueText = reps.map { "\($0) reps" } ?? durationSeconds.map { "\(Int($0)) sec" } ?? ""
            if let w = weight {
                return "\(valueText)  ·  \(WeightFormatter.format(w, unitSystem: appState.unitSystem))"
            }
            return valueText.isEmpty ? "Logged" : valueText

        case .notPerformed:
            return "Skipped"

        default:
            // Show target values so user has a mental picture of what's expected
            let valueText: String
            if exercise.defaultLoggingType == .duration, let t = set.targetDuration {
                valueText = "\(Int(t)) sec"
            } else if let r = set.targetReps {
                valueText = "\(r) reps"
            } else {
                valueText = "—"
            }
            if let w = set.targetWeight {
                return "\(valueText)  ·  \(WeightFormatter.format(w, unitSystem: appState.unitSystem))"
            }
            return valueText
        }
    }

    private func completionDot(for exercise: ActiveSessionContext.ExerciseContext) -> some View {
        let logged = exercise.setContexts.filter {
            if case .logged = $0.lifecycleState { return true }
            return false
        }.count
        let total = exercise.setContexts.count

        let symbol: String
        let color: Color
        if logged == 0 {
            symbol = "circle"
            color = .white.opacity(0.25)
        } else if logged == total {
            symbol = "circle.fill"
            color = Color.ironiqGreen.opacity(0.8)
        } else {
            symbol = "circle.lefthalf.filled"
            color = .white.opacity(0.5)
        }
        return Image(systemName: symbol)
            .font(.caption)
            .foregroundStyle(color)
    }

    // MARK: - Computed helpers

    private var loggedSetCount: Int {
        sessionVM.exercises.flatMap(\.setContexts).filter {
            if case .logged = $0.lifecycleState { return true }
            return false
        }.count
    }

    private var totalSetCount: Int {
        sessionVM.exercises.flatMap(\.setContexts).count
    }
}

private struct AddExerciseToWorkoutView: View {
    let exercise: ExerciseDTO
    let onAdd: ([CreateTemplateSetInput]) -> Void
    let onBack: () -> Void
    @State private var setRows: [ActiveSetPlanRow]
    @State private var restSeconds = 30

    init(exercise: ExerciseDTO, onAdd: @escaping ([CreateTemplateSetInput]) -> Void, onBack: @escaping () -> Void) {
        self.exercise = exercise
        self.onAdd = onAdd
        self.onBack = onBack
        _setRows = State(initialValue: [ActiveSetPlanRow(defaultType: exercise.defaultLoggingType)])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("Set targets guide the workout. Actual reps, duration, and weight are recorded while training.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rest target for \(exercise.name)", systemImage: "timer")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        Stepper("\(restSeconds)s between sets", value: $restSeconds, in: 0...600, step: 5)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                            .tint(Color.ironiqOrange)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(activeSetEntries) { entry in
                        activeSetRow(id: entry.id)
                    }

                    HStack(spacing: 10) {
                        Button {
                            setRows.append(ActiveSetPlanRow(defaultType: setRows.last?.targetType ?? .reps))
                        } label: {
                            Label("Set", systemImage: "plus")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.ironiqOrange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.ironiqOrange.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("active_add_set_button")

                        Spacer()
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                IroniqButton("Done") {
                    onAdd(setRows.map { row in
                        CreateTemplateSetInput(
                            targetReps: row.targetType == .reps ? row.targetReps : nil,
                            targetDuration: row.targetType == .duration ? Double(row.targetDurationSeconds) : nil,
                            restDuration: Double(restSeconds)
                        )
                    })
                }
                .accessibilityIdentifier("confirm_active_add_exercise_button")
            }
            .padding(18)
        }
        .background(Color.ironiqDark)
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", action: onBack)
            }
        }
    }

    @ViewBuilder
    private func activeSetRow(id: UUID) -> some View {
        if let index = activeSetIndex(id: id) {
            VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Set \(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 44, alignment: .leading)

                activeTargetTypeSwitch(id: id)

                Spacer(minLength: 8)

                if setRows.count > 1 {
                    Button {
                        guard let currentIndex = activeSetIndex(id: id) else { return }
                        setRows.remove(at: currentIndex)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(Color.ironiqRed.opacity(0.8))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityIdentifier("active_remove_set_button")
                }
            }

            if activeSetTargetType(id: id) == .duration {
                targetNumberField(label: "Target duration", value: activeIntBinding(id: id, keyPath: \.targetDurationSeconds), placeholder: "30")
                    .accessibilityIdentifier("active_target_duration_field")
            } else {
                targetNumberField(label: "Target reps", value: activeIntBinding(id: id, keyPath: \.targetReps), placeholder: "10")
                    .accessibilityIdentifier("active_target_reps_field")
            }
        }
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var activeSetEntries: [SetRowEntry] {
        setRows.enumerated().map { offset, row in
            SetRowEntry(id: row.id, index: offset)
        }
    }

    private func activeSetIndex(id: UUID) -> Int? {
        setRows.firstIndex { $0.id == id }
    }

    private func activeSetTargetType(id: UUID) -> SetLoggingType? {
        setRows.first { $0.id == id }?.targetType
    }

    private func activeTargetTypeSwitch(id: UUID) -> some View {
        let isDuration = Binding<Bool>(
            get: {
                activeSetTargetType(id: id) == .duration
            },
            set: {
                guard let index = activeSetIndex(id: id) else { return }
                setRows[index].targetType = $0 ? .duration : .reps
            }
        )
        return HStack(spacing: 6) {
            Text("Reps")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isDuration.wrappedValue ? .white.opacity(0.38) : Color.ironiqOrange)
            Toggle("", isOn: isDuration)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.72)
                .tint(Color.ironiqOrange)
                .frame(width: 44)
            Text("Time")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isDuration.wrappedValue ? Color.ironiqOrange : .white.opacity(0.38))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.055))
        .clipShape(Capsule())
    }

    private func activeIntBinding(id: UUID, keyPath: WritableKeyPath<ActiveSetPlanRow, Int>) -> Binding<Int> {
        Binding<Int>(
            get: {
                setRows.first { $0.id == id }?[keyPath: keyPath] ?? 0
            },
            set: { newValue in
                guard let index = activeSetIndex(id: id) else { return }
                setRows[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func targetNumberField(label: String, value: Binding<Int>, placeholder: String) -> some View {
        let defaultValue = Int(placeholder) ?? 0
        return HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            DefaultPlaceholderIntField(value: value, defaultValue: defaultValue, width: 74)
                .font(.headline.monospacedDigit().weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct SetRowEntry: Identifiable {
    let id: UUID
    let index: Int
}

private struct ActiveSetPlanRow: Identifiable {
    let id = UUID()
    var targetType: SetLoggingType
    var targetReps: Int = 10
    var targetDurationSeconds: Int = 30

    init(defaultType: SetLoggingType) {
        targetType = defaultType
        if defaultType == .duration {
            targetReps = 0
            targetDurationSeconds = 30
        }
    }
}

struct ActiveWorkoutCard: View {
    @Environment(SessionViewModel.self) private var sessionVM

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ACTIVE")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.ironiqGreen)
                    .clipShape(Capsule())
                Spacer()
                Label(sessionVM.sessionElapsed.timerFormatted, systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
            }

            Text(workoutName)
                .font(.title.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack {
                Label("\(completedExercises) / \(sessionVM.exercises.count) exercises", systemImage: "checkmark.circle.fill")
                Spacer()
                Text(currentExercise)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.ironiqOrange.opacity(0.85), Color.ironiqDark.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var workoutName: String {
        sessionVM.workoutName
    }

    private var completedExercises: Int {
        sessionVM.exercises.filter { $0.status == .complete || $0.status == .notPerformed }.count
    }

    private var currentExercise: String {
        sessionVM.currentExercise?.exerciseName ?? "Add an exercise"
    }
}

private struct TemplateSelectView: View {
    @Environment(TemplateViewModel.self) private var templateVM
    @Environment(\.dismiss) private var dismiss
    let onSelect: (TemplateDTO) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templateVM.templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a template from Templates first.")
                    )
                    .foregroundStyle(.white)
                } else {
                    List {
                        ForEach(templateVM.templates) { template in
                            Button {
                                onSelect(template)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(template.name)
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(template.exercises.count) exercises")
                                        .frame(width: 92, alignment: .trailing)
                                    Text(template.targetCompletionTime.timerFormatted)
                                        .frame(width: 64, alignment: .trailing)
                                }
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.68))
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.ironiqDark)
            .navigationTitle("Select Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

}

#Preview {
    StartView(showWorkoutDashboard: .constant(false), showLogOnDashboardOpen: .constant(false), showExercisePicker: .constant(false))
        .environment(AppState())
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        ))
}
