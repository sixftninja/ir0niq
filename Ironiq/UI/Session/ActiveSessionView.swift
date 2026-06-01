import SwiftUI

struct ActiveSessionView: View {
    @Binding private var openLogOnAppear: Bool
    @Environment(SessionViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showEndConfirm = false
    @State private var showReview = false
    @State private var showLogInput = false
    @State private var showCountdown = true
    @State private var countdown = 5
    @State private var emptyHintOffset: CGFloat = 0
    private let onAddExercise: () -> Void

    init(openLogOnAppear: Binding<Bool> = .constant(false), onAddExercise: @escaping () -> Void = {}) {
        _openLogOnAppear = openLogOnAppear
        self.onAddExercise = onAddExercise
    }

    var body: some View {
        ZStack {
            dashboardBackground
            if showCountdown {
                countdownView
            } else {
                dashboard
            }
        }
        .task {
            showCountdown = !vm.hasShownStartCountdown
            guard showCountdown else { return }
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
            showCountdown = false
            vm.markStartCountdownShown()
        }
        .alert("Workout Error", isPresented: Binding(
            get: { vm.showAlert },
            set: { vm.showAlert = $0 }
        )) {
            Button("OK") { vm.showAlert = false }
        } message: {
            Text(vm.alertMessage ?? "Something went wrong.")
        }
        .sheet(isPresented: $showReview) {
            ReviewBeforeSavingView(unloggedSets: vm.unloggedSets) {
                Task {
                    await vm.confirmEnd()
                    showReview = false
                }
            }
        }
        .sheet(isPresented: $showLogInput) {
            if let set = vm.currentSet {
                InputFaceView(set: set, defaultLoggingType: vm.currentExercise?.defaultLoggingType ?? .reps) { reps, durationSeconds, weight in
                    Task {
                        await vm.logCurrentSet(reps: reps, durationSeconds: durationSeconds, weight: weight)
                        await vm.advanceToNext()
                        showLogInput = false
                    }
                }
                .presentationDetents([.large])
            }
        }
        .sensoryFeedback(.warning, trigger: shouldShowRestPrompt)
        .onAppear {
            if openLogOnAppear, vm.currentSet != nil {
                openLogOnAppear = false
                showLogInput = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height > 70 {
                        dismiss()
                    }
                }
        )
    }

    private var dashboardBackground: some View {
        LinearGradient(
            colors: [
                Color.ironiqOrange,
                Color(red: 0.86, green: 0.28, blue: 0.02),
                Color.ironiqDark
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var countdownView: some View {
        VStack(spacing: 24) {
            Text("Starting Workout")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("\(max(countdown, 1))")
                .font(.system(size: 112, weight: .black, design: .rounded))
                .foregroundStyle(Color.ironiqOrange)
                .monospacedDigit()
            Button("Skip Countdown") {
                showCountdown = false
                vm.markStartCountdownShown()
            }
            .accessibilityIdentifier("skip_countdown_button")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            topControls
                .padding(.horizontal, 20)
                .padding(.top, 18)

            Spacer(minLength: 18)

            if vm.exercises.isEmpty {
                emptyWorkoutView
            } else {
                currentSetSurface
            }

            Spacer(minLength: 18)

            primaryControls
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
        }
    }

    private var topControls: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 46, height: 5)
                Text("Swipe down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Label(vm.sessionElapsed.timerFormatted, systemImage: "timer")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    Task { await endWorkout() }
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.22))
                        .clipShape(Circle())
                }
                .accessibilityLabel("End workout")
            }
        }
    }

    private var emptyWorkoutView: some View {
        VStack(spacing: 18) {
            Button(action: onAddExercise) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add first exercise")
            .accessibilityIdentifier("dashboard_add_first_exercise_button")

            Text("Workout Active")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)
                .accessibilityIdentifier("workout_active_title")
        }
        .padding(32)
        .offset(y: emptyHintOffset)
        .task(id: vm.exercises.isEmpty) {
            guard vm.exercises.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeInOut(duration: 0.45)) { emptyHintOffset = 24 }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) { emptyHintOffset = 0 }
        }
    }

    private var currentSetSurface: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(vm.currentExercise?.exerciseName ?? "Exercise")
                    .font(.system(.title2, design: .default).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("Set \(vm.currentSetIndex + 1) of \(vm.currentExercise?.setContexts.count ?? 0)")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 10) {
                metricRow(title: "Target", value: currentTargetText, icon: "scope")
                metricRow(title: "Last set", value: previousSetText, icon: "checkmark.circle")
                metricRow(title: "Previous rest", value: previousRestText, icon: "clock.arrow.circlepath", valueColor: previousRestColor)
                if case .resting = vm.currentSet?.lifecycleState {
                    restMetric
                }
            }
            .padding(18)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func metricRow(title: String, value: String, icon: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.ironiqOrange)
                .frame(width: 24)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Spacer(minLength: 12)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var restMetric: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Resting", systemImage: "pause.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(vm.restElapsed.timerFormatted)
                    .font(.title2.weight(.black).monospacedDigit())
                    .foregroundStyle(restOverage > 0 ? Color.ironiqOrange : Color.ironiqGreen)
            }
            HStack {
                Text("Target \(restTarget.timerFormatted)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if restOverage > 0 {
                    Text("+\(restOverage.timerFormatted) over")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ironiqOrange)
                }
            }
        }
        .padding(.top, 6)
    }

    private var primaryControls: some View {
        VStack(spacing: 12) {
            if vm.exercises.isEmpty {
                EmptyView()
            } else if let set = vm.currentSet {
                switch set.lifecycleState {
                case .pending, .inProgress:
                    FinishSetButton(needsAttention: shouldShowRestPrompt) {
                        Task { await finishSetAndLog() }
                    }
                    .accessibilityIdentifier("finish_set_button")
                case .resting:
                    IroniqButton("Log Set") {
                        showLogInput = true
                    }
                    .accessibilityIdentifier("log_set_button")
                case .awaitingInput:
                    IroniqButton("Log Set") {
                        showLogInput = true
                    }
                    .accessibilityIdentifier("log_set_button")
                case .logged:
                    IroniqButton(isLastSet ? "End" : "Next") {
                        Task {
                            if isLastSet {
                                await endWorkout()
                            } else {
                                await vm.advanceToNext()
                            }
                        }
                    }
                    .accessibilityIdentifier(isLastSet ? "end_workout_button" : "advance_button")
                case .notPerformed:
                    IroniqButton(isLastSet ? "End" : "Next") {
                        Task {
                            if isLastSet {
                                await endWorkout()
                            } else {
                                await vm.advanceToNext()
                            }
                        }
                    }
                }
            } else {
                IroniqButton("Finish Workout") {
                    Task { await endWorkout() }
                }
            }
        }
    }


    private func endWorkout() async {
        _ = await vm.endSession()
        await vm.confirmEnd()
    }

    private var isLastSet: Bool {
        guard let exercise = vm.currentExercise else { return false }
        return vm.currentExerciseIndex == vm.exercises.count - 1
            && vm.currentSetIndex == exercise.setContexts.count - 1
    }

    private func finishSetAndLog() async {
        let target = vm.currentSet?.targetRestDuration ?? 30
        await vm.tapRest(targetRestDuration: target)
        showLogInput = true
    }

    private var workoutName: String {
        vm.workoutName
    }

    private var previousSetText: String {
        guard let previous = previousSet else { return "Unavailable" }
        guard case .logged(let reps, let durationSeconds, let weight) = previous.lifecycleState else { return "Unavailable" }
        guard reps != nil || durationSeconds != nil else { return "Unavailable" }
        let resultText = reps.map { "\($0) reps" } ?? durationSeconds.map { "\(Int($0)) sec" } ?? "Unavailable"
        let weightText = weight.map { WeightFormatter.format($0, unitSystem: appState.unitSystem) } ?? "Bodyweight"
        return "\(resultText) | \(weightText)"
    }

    private var currentTargetText: String {
        guard let set = vm.currentSet else { return "None" }
        if let targetReps = set.targetReps {
            return "\(targetReps) reps"
        }
        if let targetDuration = set.targetDuration {
            return "\(Int(targetDuration)) sec"
        }
        return "Open"
    }

    private var previousRestText: String {
        guard let previous = previousSet, let actual = restDuration(for: previous) else { return "Unavailable" }
        let target = previous.targetRestDuration ?? 30
        let delta = actual - target
        if delta > 0 {
            return "\(actual.timerFormatted) | +\(delta.timerFormatted)"
        }
        return "\(actual.timerFormatted) | target \(target.timerFormatted)"
    }

    private var previousRestColor: Color {
        guard let previous = previousSet, let actual = restDuration(for: previous) else { return .white.opacity(0.62) }
        let target = previous.targetRestDuration ?? 30
        return actual > target ? Color.ironiqOrange : Color.ironiqGreen
    }

    private func restDuration(for set: ActiveSessionContext.ExerciseContext.SetContext) -> TimeInterval? {
        guard let start = set.restStart, let end = set.restEnd else { return nil }
        return max(0, end.timeIntervalSince(start))
    }

    private var previousSet: ActiveSessionContext.ExerciseContext.SetContext? {
        guard let exercise = vm.currentExercise else { return nil }
        let index = vm.currentSetIndex - 1
        guard index >= 0, index < exercise.setContexts.count else { return nil }
        return exercise.setContexts[index]
    }

    private var restTarget: TimeInterval {
        vm.currentSet?.targetRestDuration ?? 30
    }

    private var restOverage: TimeInterval {
        max(0, vm.restElapsed - restTarget)
    }

    private var shouldShowRestPrompt: Bool {
        guard case .inProgress = vm.currentSet?.lifecycleState else { return false }
        return vm.setElapsed >= Double(appState.restReminderSeconds)
    }
}

private struct FinishSetButton: View {
    let needsAttention: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: needsAttention ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                Text(needsAttention ? "Finished set? Log it" : "Finish Set")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(needsAttention ? .black : Color.ironiqOrange)
            .frame(maxWidth: .infinity)
            .padding()
            .background(needsAttention ? Color.ironiqGreen : Color.ironiqOrange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(needsAttention ? Color.white.opacity(pulse ? 0.95 : 0.25) : Color.ironiqOrange.opacity(0.4), lineWidth: needsAttention ? 3 : 1)
            )
            .scaleEffect(needsAttention && pulse ? 1.025 : 1)
            .shadow(color: needsAttention ? Color.ironiqGreen.opacity(pulse ? 0.45 : 0.12) : .clear, radius: needsAttention ? 18 : 0)
        }
        .onAppear { pulse = needsAttention }
        .onChange(of: needsAttention) { _, newValue in pulse = newValue }
        .animation(needsAttention ? .easeInOut(duration: 0.72).repeatForever(autoreverses: true) : .default, value: pulse)
    }
}

extension SessionEngineState {
    var isActive: Bool {
        if case .active = self { return true }
        if case .paused = self { return true }
        return false
    }
}

#Preview {
    ActiveSessionView()
        .environment(AppState())
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(HistoryViewModel(
            sessionRepo: PreviewRepositories.session,
            appState: AppState()
        ))
}
