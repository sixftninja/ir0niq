import Foundation
import Observation

/// Bridges SessionEngine (actor) to the @MainActor SwiftUI layer.
/// All properties are read on MainActor; all mutations go through the engine.
@MainActor
@Observable
final class SessionViewModel {

    // MARK: - Engine state mirror

    private(set) var engineState: SessionEngineState = .idle {
        didSet { isSessionActive = engineState.isActive }
    }
    // Stored @Observable property so fullScreenCover binding is reliably tracked
    private(set) var isSessionActive: Bool = false
    private(set) var exercises: [ActiveSessionContext.ExerciseContext] = []
    private(set) var templateId: UUID?
    private(set) var workoutName: String = "Workout"
    private(set) var currentExerciseIndex: Int = 0
    private(set) var currentSetIndex: Int = 0

    // MARK: - Timer state (refreshed every 500 ms while active)

    private(set) var sessionElapsed: TimeInterval = 0
    private(set) var setElapsed: TimeInterval = 0
    private(set) var restElapsed: TimeInterval = 0
    private(set) var restRemaining: TimeInterval = 0
    private(set) var hasRestTarget: Bool = false

    // MARK: - Session end flow

    private(set) var unloggedSets: [UnloggedSetInfo] = []
    private(set) var completedSessionId: UUID?
    private(set) var hasShownStartCountdown = false

    // MARK: - Error / alert

    var alertMessage: String? = nil
    var showAlert: Bool = false

    // MARK: - Dependencies

    private let engine: SessionEngine
    private var tickerTask: Task<Void, Never>?
    private var observerTask: Task<Void, Never>?

    init(engine: SessionEngine) {
        self.engine = engine
        startObserving()
    }

    // Note: Task cancellation happens naturally via [weak self] captures when this object is deallocated.

    // MARK: - Engine action wrappers (all @MainActor, throw on error → set alertMessage)

    func selectTemplate(_ templateId: UUID) async {
        do { try await engine.selectTemplate(templateId) }
        catch { setAlert(error) }
    }

    @discardableResult
    func startSession() async -> Bool {
        hasShownStartCountdown = false
        do { _ = try await engine.startSession() }
        catch { setAlert(error); await refreshStateAndContext(); return false }
        await refreshStateAndContext()
        return true
    }

    @discardableResult
    func startTemplateSession(_ templateId: UUID) async -> Bool {
        hasShownStartCountdown = false
        do {
            let currentState = await engine.state
            if case .active = currentState { await refreshStateAndContext(); return true }
            if case .paused = currentState { await refreshStateAndContext(); return true }
            await engine.prepareForNewSession()
            try await engine.selectTemplate(templateId)
            _ = try await engine.startSession()
            await refreshStateAndContext()
            return true
        } catch {
            setAlert(error)
            await refreshStateAndContext()
            return false
        }
    }

    @discardableResult
    func startAdHocSession() async -> Bool {
        hasShownStartCountdown = false
        do {
            let currentState = await engine.state
            if case .active = currentState { await refreshStateAndContext(); return true }
            if case .paused = currentState { await refreshStateAndContext(); return true }
            await engine.prepareForNewSession()
            _ = try await engine.startAdHocSession()
            await refreshStateAndContext()
            return true
        } catch {
            setAlert(error)
            await refreshStateAndContext()
            return false
        }
    }

    func beginCurrentSet() async {
        do { try await engine.beginCurrentSet() }
        catch { setAlert(error) }
        await refreshContext()
    }

    func tapRest(targetRestDuration: TimeInterval? = nil) async {
        do { try await engine.tapRest(targetRestDuration: targetRestDuration) }
        catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func restEnded() async {
        do { try await engine.restEnded() }
        catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func logCurrentSet(reps: Int?, durationSeconds: TimeInterval? = nil, weight: Double?) async {
        do { try await engine.logCurrentSet(reps: reps, durationSeconds: durationSeconds, weight: weight) }
        catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func advanceToNext() async {
        do { try await engine.advanceToNext() }
        catch SessionEngineError.allSetsNotLogged {
            setAlert(message: "Please log all sets before moving to the next exercise.")
        } catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func pauseSession() async {
        do { try await engine.pauseSession() }
        catch { setAlert(error) }
    }

    func resumeSession() async {
        do { try await engine.resumeSession() }
        catch { setAlert(error) }
    }

    /// Transitions to .ending and returns unlogged sets for review.
    func endSession() async -> [UnloggedSetInfo] {
        do {
            let sets = try await engine.endSession()
            unloggedSets = sets
            return sets
        } catch {
            setAlert(error)
            return []
        }
    }

    func confirmEnd() async {
        do {
            try await engine.confirmEnd()
            if case .ended(let sessionId) = await engine.state {
                completedSessionId = sessionId
            }
        } catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func cancelEnd() {
        Task {
            do { try await engine.cancelEnd() }
            catch { setAlert(error) }
        }
    }

    func addUnplannedExercise(
        exerciseId: UUID,
        exerciseName: String,
        setCount: Int,
        defaultLoggingType: SetLoggingType = .reps
    ) async {
        do {
            try await engine.addUnplannedExercise(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                setCount: setCount,
                defaultLoggingType: defaultLoggingType
            )
        }
        catch { setAlert(error) }
        await refreshContext()
    }

    func addUnplannedExercise(
        exerciseId: UUID,
        exerciseName: String,
        sets: [CreateTemplateSetInput],
        defaultLoggingType: SetLoggingType = .reps
    ) async {
        do {
            try await engine.addUnplannedExercise(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                sets: sets,
                defaultLoggingType: defaultLoggingType
            )
        }
        catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func skipCurrentExercise() async {
        do { try await engine.skipCurrentExercise() }
        catch { setAlert(error) }
        await refreshStateAndContext()
    }

    func reset() async {
        await engine.reset()
        tickerTask?.cancel()
        tickerTask = nil
        hasShownStartCountdown = false
        sessionElapsed = 0
        setElapsed = 0
        restElapsed = 0
        restRemaining = 0
        unloggedSets = []
        completedSessionId = nil
    }

    func markStartCountdownShown() {
        hasShownStartCountdown = true
    }

    // MARK: - Computed helpers

    var isEndingSession: Bool {
        if case .ending = engineState { return true }
        return false
    }

    var currentExercise: ActiveSessionContext.ExerciseContext? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var currentSet: ActiveSessionContext.ExerciseContext.SetContext? {
        guard let ex = currentExercise,
              currentSetIndex < ex.setContexts.count else { return nil }
        return ex.setContexts[currentSetIndex]
    }

    var exerciseProgress: String {
        "\(currentExerciseIndex + 1) / \(exercises.count)"
    }

    var setProgress: String {
        let total = currentExercise?.setContexts.count ?? 0
        return "\(currentSetIndex + 1) / \(total)"
    }

    // MARK: - Private

    private func startObserving() {
        // Capture the nonisolated stream synchronously before the Task starts.
        let stream = engine.stateUpdates
        observerTask = Task { @MainActor [weak self] in
            for await newState in stream {
                guard let self else { return }
                self.engineState = newState
                await self.refreshContext()
                switch newState {
                case .active:
                    self.startTicker()
                case .paused, .ending, .ended, .idle, .templateSelected:
                    self.stopTicker()
                }
            }
        }
    }

    private func refreshStateAndContext() async {
        engineState = await engine.state
        await refreshContext()
    }

    private func refreshContext() async {
        let ctx = await engine.sessionContext
        exercises = ctx?.exercises ?? []
        templateId = ctx?.templateId
        workoutName = ctx?.workoutName ?? "Workout"
        currentExerciseIndex = ctx?.currentExerciseIndex ?? 0
        currentSetIndex = ctx?.currentSetIndex ?? 0
    }

    private func startTicker() {
        guard tickerTask == nil || tickerTask!.isCancelled else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                await self?.tick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() async {
        guard case .active = engineState else { return }
        let ctx = await engine.sessionContext
        guard let ctx else { return }
        let now = Date()
        sessionElapsed = now.timeIntervalSince(ctx.sessionStartedAt)

        guard let set = ctx.currentSet else { return }
        switch set.lifecycleState {
        case .inProgress(let startedAt):
            setElapsed = now.timeIntervalSince(startedAt)
            restElapsed = 0; restRemaining = 0; hasRestTarget = false
        case .resting(_, let target):
            let elapsed = now.timeIntervalSince(set.restStart ?? now)
            restElapsed = elapsed
            hasRestTarget = target != nil
            if let t = target {
                let remaining = t - elapsed
                restRemaining = max(0, remaining)
            }
        default:
            setElapsed = 0; restElapsed = 0; restRemaining = 0; hasRestTarget = false
        }
    }

    private func setAlert(_ error: Error) {
        setAlert(message: error.localizedDescription)
    }

    private func setAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}
