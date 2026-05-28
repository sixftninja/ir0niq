import SwiftUI

struct ActiveSessionView: View {
    @Environment(SessionViewModel.self) private var vm
    @State private var showEndConfirm = false
    @State private var showReview = false
    @State private var showSummary = false

    var body: some View {
        ZStack {
            Color.forgeDark.ignoresSafeArea()

            VStack(spacing: 0) {
                sessionHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.top, 8)

                // Face view
                faceArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }

            // Paused overlay
            if case .paused = vm.engineState {
                PausedFaceView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        // End confirm dialog
        .confirmationDialog(
            "End Session?",
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task {
                    let unlogged = await vm.endSession()
                    if unlogged.isEmpty {
                        await vm.confirmEnd()
                        showSummary = true
                    } else {
                        showReview = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your session will be saved.")
        }
        // Review sheet (edge case 3)
        .sheet(isPresented: $showReview) {
            ReviewBeforeSavingView(unloggedSets: vm.unloggedSets) {
                Task {
                    await vm.confirmEnd()
                    showReview = false
                    showSummary = true
                }
            }
        }
        // Summary sheet
        .sheet(isPresented: $showSummary) {
            SessionSummaryView()
        }
        .animation(.easeInOut(duration: 0.2), value: vm.engineState.isActive)
    }

    // MARK: - Header

    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentExercise?.exerciseName ?? "—")
                    .font(.title3).bold()
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("exercise_name_label")
                Text("Set \(vm.setProgress)  ·  Exercise \(vm.exerciseProgress)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityIdentifier("set_progress_label")
            }
            Spacer()
            TimerView(
                value: vm.sessionElapsed,
                color: .white.opacity(0.6),
                font: .system(size: 18, weight: .semibold, design: .monospaced)
            )
            .accessibilityIdentifier("session_timer")
        }
        .padding(.vertical, 12)
    }

    // MARK: - Face routing

    @ViewBuilder
    private var faceArea: some View {
        if let set = vm.currentSet {
            switch set.lifecycleState {
            case .resting:
                RestFaceView(set: set)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id("rest_\(set.sessionSetId)")

            case .awaitingInput:
                awaitingInputView(set: set)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id("input_\(set.sessionSetId)")

            default:
                SetFaceView(set: set)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ))
                    .id("set_\(set.sessionSetId)_\(String(describing: set.lifecycleState))")
            }
        } else {
            allExercisesDoneView
        }
    }

    @ViewBuilder
    private func awaitingInputView(set: ActiveSessionContext.ExerciseContext.SetContext) -> some View {
        VStack {
            Spacer()
            Text("Log Your Set")
                .font(.title2).bold()
                .foregroundStyle(.white)
            Spacer()
            InputFaceView(set: set) { reps, weight in
                Task {
                    await vm.logCurrentSet(reps: reps, weight: weight)
                    await vm.advanceToNext()
                }
            }
            .frame(maxHeight: 300)
            Spacer()
        }
    }

    private var allExercisesDoneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.forgeGreen)
            Text("All Exercises Done!")
                .font(.title2).bold()
                .foregroundStyle(.white)
            ForgeButton("Finish Session") {
                showEndConfirm = true
            }
            .accessibilityIdentifier("finish_session_button")
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Exercise navigation
            Button {
                Task { await vm.skipCurrentExercise() }
            } label: {
                Image(systemName: "forward.fill")
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.15))
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("skip_exercise_button")
            .accessibilityLabel("Skip exercise")

            Spacer()

            // Advance (after logging)
            if case .logged = vm.currentSet?.lifecycleState {
                ForgeButton("Next →", style: .primary) {
                    Task { await vm.advanceToNext() }
                }
                .accessibilityIdentifier("advance_button")
                .frame(maxWidth: 160)
            }

            Spacer()

            // Pause / End
            Menu {
                Button {
                    Task { await vm.pauseSession() }
                } label: {
                    Label("Pause Session", systemImage: "pause.fill")
                }

                Button(role: .destructive) {
                    showEndConfirm = true
                } label: {
                    Label("End Session", systemImage: "stop.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("session_menu_button")
        }
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
        .environment(SessionViewModel(engine: SessionEngine(
            templateRepository: PreviewRepositories.template,
            sessionRepository: PreviewRepositories.session
        )))
        .environment(HistoryViewModel(
            sessionRepo: PreviewRepositories.session,
            appState: AppState()
        ))
}
