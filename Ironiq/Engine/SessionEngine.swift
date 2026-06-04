import Foundation
import SwiftData

// MARK: - Set lifecycle state (engine-internal, not persisted directly)

enum SetLifecycleState: Equatable, Sendable {
    case pending
    case inProgress(startedAt: Date)
    case resting(setEndedAt: Date, targetRestDuration: TimeInterval?)
    case awaitingInput
    case logged(reps: Int?, durationSeconds: TimeInterval?, weight: Double?)
    case notPerformed
}

// MARK: - Active session context (pure in-memory state)

struct ActiveSessionContext: Sendable {
    var sessionId: UUID
    var templateId: UUID?
    var workoutName: String
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0
    var exercises: [ExerciseContext]
    var pauseRecordId: UUID?
    var totalPauseDuration: TimeInterval = 0
    var sessionStartedAt: Date
    var lastInteractionAt: Date

    struct ExerciseContext: Sendable {
        let sessionExerciseId: UUID
        let exerciseId: UUID
        let exerciseName: String
        let defaultLoggingType: SetLoggingType
        var setContexts: [SetContext]
        var status: SessionExerciseStatus = .pending

        struct SetContext: Sendable {
            let sessionSetId: UUID
            var order: Int
            var lifecycleState: SetLifecycleState = .pending
            var reps: Int?
            var durationSeconds: TimeInterval?
            var weight: Double?
            var isUnrecorded: Bool = false
            var setTimerStart: Date?
            var setTimerEnd: Date?
            var restStart: Date?
            var restEnd: Date?
            // Template targets — carried for UI display and default values
            let targetReps: Int?
            let targetDuration: TimeInterval?
            let targetWeight: Double?
            let targetRestDuration: TimeInterval?

            init(
                sessionSetId: UUID,
                order: Int,
                targetReps: Int? = nil,
                targetDuration: TimeInterval? = nil,
                targetWeight: Double? = nil,
                targetRestDuration: TimeInterval? = nil
            ) {
                self.sessionSetId = sessionSetId
                self.order = order
                self.targetReps = targetReps
                self.targetDuration = targetDuration
                self.targetWeight = targetWeight
                self.targetRestDuration = targetRestDuration
            }
        }
    }

    var currentExercise: ExerciseContext? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var currentSet: ExerciseContext.SetContext? {
        guard let ex = currentExercise,
              currentSetIndex < ex.setContexts.count else { return nil }
        return ex.setContexts[currentSetIndex]
    }
}

// MARK: - Global accessor for AppIntents (set once at app startup)

// SessionEngine.current is kept for any remaining call sites but now delegates
// to SessionIntentBridge so we have a single, isolation-safe registration point.
extension SessionEngine {
    /// Deprecated — use SessionIntentBridge.shared instead.
    static var current: SessionEngine? {
        get { MainActor.assumeIsolated { SessionIntentBridge.shared.engine() } }
        set { if let e = newValue { MainActor.assumeIsolated { SessionIntentBridge.shared.setEngine(e) } } }
    }
}

// MARK: - Unlogged set info (returned by endSession for review)

struct UnloggedSetInfo: Sendable, Equatable {
    let setId: UUID
    let exerciseId: UUID
    let setOrder: Int
}

// MARK: - Session Engine

/// Central state machine for an active workout session.
/// Single source of truth. Injected at app level; treat as a singleton in production.
actor SessionEngine {

    // MARK: - Constants

    static let maxSessionDuration: TimeInterval = 3 * 60 * 60   // 3 hours (edge case 5)
    static let idleAutoEndDuration: TimeInterval = 30 * 60      // 30 min idle (edge case 5)
    static let nudgeMultiplier: Double = 2.0                    // Nudge at 2× rest time (edge case 1)

    // MARK: - State

    private(set) var state: SessionEngineState = .idle
    var sessionContext: ActiveSessionContext?          // internal for @testable access
    private var selectedTemplateId: UUID?

    // MARK: - Dependencies

    private let templateRepository: any TemplateRepositoryProtocol
    private let sessionRepository: any SessionRepositoryProtocol
    private let timerSystem: TimerSystem
    var healthKitService: (any HealthKitServiceProtocol)?
    var iCloudService: (any iCloudServiceProtocol)?
    var watchSyncService: (any WatchSyncServiceProtocol)?
    var unitSystem: String = "metric"
    private var lastEndedDurationSeconds: TimeInterval = 0
    private var lastEndedVolumeKg: Double = 0

    func updateUnitSystem(_ system: String) { unitSystem = system }

    // MARK: - State stream (observed by UI in Phase 3)

    nonisolated let stateUpdates: AsyncStream<SessionEngineState>
    private let stateUpdatesContinuation: AsyncStream<SessionEngineState>.Continuation

    // MARK: - Init / Factory

    init(
        templateRepository: any TemplateRepositoryProtocol,
        sessionRepository: any SessionRepositoryProtocol,
        timerSystem: TimerSystem = TimerSystem(),
        healthKitService: (any HealthKitServiceProtocol)? = nil,
        iCloudService: (any iCloudServiceProtocol)? = nil,
        watchSyncService: (any WatchSyncServiceProtocol)? = nil
    ) {
        let (stream, continuation) = AsyncStream<SessionEngineState>.makeStream()
        self.stateUpdates = stream
        self.stateUpdatesContinuation = continuation
        self.templateRepository = templateRepository
        self.sessionRepository = sessionRepository
        self.timerSystem = timerSystem
        self.healthKitService = healthKitService
        self.iCloudService = iCloudService
        self.watchSyncService = watchSyncService
    }

    static func make(modelContainer: ModelContainer) -> SessionEngine {
        // WatchSyncService.shared is @MainActor — accessed at call site which is already MainActor
        let watchSync = MainActor.assumeIsolated { WatchSyncService.shared }
        return SessionEngine(
            templateRepository: TemplateRepository(modelContainer: modelContainer),
            sessionRepository: SessionRepository(modelContainer: modelContainer),
            healthKitService: HealthKitService.shared,
            iCloudService: CloudStorageRouter.shared,
            watchSyncService: watchSync
        )
    }

    // MARK: - Rename current session

    func renameCurrentSession(_ name: String) {
        guard var context = sessionContext else { return }
        context.workoutName = name
        sessionContext = context
    }

    // MARK: - New session preparation

    /// Cleans up any leftover state from a previous session so the engine
    /// is in `.idle` and ready to accept a new `selectTemplate` or `startAdHocSession`.
    /// Safe to call from any state; returns without throwing.
    func prepareForNewSession() async {
        switch state {
        case .idle:
            break
        case .templateSelected:
            try? clearTemplate()
        case .ending:
            try? await confirmEnd()
            if case .ended = state { await reset() }
        case .ended:
            await reset()
        case .active, .paused:
            // Already running — do not interrupt.
            break
        }
    }

    // MARK: - Template selection

    func selectTemplate(_ templateId: UUID) throws {
        clearEndedSessionIfNeeded()
        guard case .idle = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "selectTemplate")
        }
        selectedTemplateId = templateId
        transition(to: .templateSelected(templateId: templateId))
    }

    func clearTemplate() throws {
        guard case .templateSelected = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "clearTemplate")
        }
        selectedTemplateId = nil
        transition(to: .idle)
    }

    // MARK: - Start session

    /// Creates a session from the selected template and transitions to active.
    func startSession() async throws -> UUID {
        guard case .templateSelected(let templateId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "startSession")
        }
        guard let template = try await templateRepository.fetchById(templateId) else {
            throw SessionEngineError.templateNotFound
        }
        return try await buildAndActivateSession(
            templateId: templateId,
            workoutName: template.name,
            exercises: template.exercises
        )
    }

    /// Starts an ad-hoc session with no template.
    func startAdHocSession() async throws -> UUID {
        clearEndedSessionIfNeeded()
        guard case .idle = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "startAdHocSession")
        }
        return try await buildAndActivateSession(templateId: nil, workoutName: "New Workout", exercises: [])
    }

    private func buildAndActivateSession(
        templateId: UUID?,
        workoutName: String,
        exercises: [TemplateExerciseDTO]
    ) async throws -> UUID {
        let now = Date()
        let sessionId = try await sessionRepository.createSession(templateId: templateId, startedAt: now)

        var exerciseContexts: [ActiveSessionContext.ExerciseContext] = []
        for (exIndex, templateExercise) in exercises.enumerated() {
            let sessionExerciseId = try await sessionRepository.addExercise(
                to: sessionId,
                exerciseId: templateExercise.exerciseId,
                order: exIndex,
                executionOrder: exIndex
            )
            var setContexts: [ActiveSessionContext.ExerciseContext.SetContext] = []
            for (setIndex, templateSet) in templateExercise.sets.enumerated() {
                let setId = try await sessionRepository.addSet(to: sessionExerciseId, order: setIndex)
                setContexts.append(.init(
                    sessionSetId: setId,
                    order: setIndex,
                    targetReps: templateSet.targetReps,
                    targetDuration: templateSet.targetDuration,
                    targetWeight: templateSet.targetWeight,
                    targetRestDuration: templateSet.restDuration
                ))
            }
            exerciseContexts.append(.init(
                sessionExerciseId: sessionExerciseId,
                exerciseId: templateExercise.exerciseId,
                exerciseName: templateExercise.exerciseName,
                defaultLoggingType: templateExercise.defaultLoggingType,
                setContexts: setContexts
            ))
        }

        sessionContext = ActiveSessionContext(
            sessionId: sessionId,
            templateId: templateId,
            workoutName: workoutName,
            exercises: exerciseContexts,
            sessionStartedAt: now,
            lastInteractionAt: now
        )
        if !exerciseContexts.isEmpty {
            var context = sessionContext!
            beginCurrentSet(in: &context, startedAt: now)
            sessionContext = context
        }

        await startTimers(sessionId: sessionId)
        transition(to: .active(sessionId: sessionId))

        // HealthKit is additive. Permission/device prompts must not block the workout UI.
        if let healthKitService {
            Task {
                try? await healthKitService.requestAuthorization()
                try? await healthKitService.startWorkout(sessionId: sessionId, startDate: now)
            }
        }

        return sessionId
    }

    // MARK: - Set lifecycle

    /// Marks the current set as in-progress and records start time.
    func beginCurrentSet() throws {
        guard case .active = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "beginCurrentSet")
        }
        guard var context = sessionContext,
              context.exercises.indices.contains(context.currentExerciseIndex),
              context.exercises[context.currentExerciseIndex].setContexts.indices.contains(context.currentSetIndex) else {
            throw SessionEngineError.setNotFound
        }
        switch context.exercises[context.currentExerciseIndex].setContexts[context.currentSetIndex].lifecycleState {
        case .pending:
            break
        case .inProgress:
            return
        default:
            throw SessionEngineError.invalidTransition(from: state, action: "beginCurrentSet: set not pending")
        }

        let now = Date()
        context.exercises[context.currentExerciseIndex].setContexts[context.currentSetIndex].setTimerStart = now
        context.exercises[context.currentExerciseIndex].setContexts[context.currentSetIndex].lifecycleState = .inProgress(startedAt: now)
        context.exercises[context.currentExerciseIndex].status = .inProgress
        context.lastInteractionAt = now
        sessionContext = context
        scheduleIdleReset(sessionId: context.sessionId)
    }

    /// Taps Rest: transitions current set from inProgress → resting.
    /// Uses the set's template rest duration by default; pass an override to change it.
    func tapRest(targetRestDuration: TimeInterval? = nil) async throws {
        guard case .active = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "tapRest")
        }
        guard var context = sessionContext else { throw SessionEngineError.setNotFound }
        let exIdx = context.currentExerciseIndex
        let setIdx = context.currentSetIndex
        if case .pending = context.exercises[exIdx].setContexts[setIdx].lifecycleState {
            beginCurrentSet(in: &context, startedAt: context.lastInteractionAt)
        }
        guard case .inProgress = context.exercises[exIdx].setContexts[setIdx].lifecycleState else {
            throw SessionEngineError.invalidTransition(from: state, action: "tapRest: set not in progress")
        }

        let now = Date()
        context.exercises[exIdx].setContexts[setIdx].setTimerEnd = now
        context.exercises[exIdx].setContexts[setIdx].restStart = now
        // Use explicit override, else fall back to the set's template target
        let effectiveRestDuration = targetRestDuration
            ?? context.exercises[exIdx].setContexts[setIdx].targetRestDuration
        context.exercises[exIdx].setContexts[setIdx].lifecycleState = .resting(
            setEndedAt: now,
            targetRestDuration: effectiveRestDuration
        )
        context.lastInteractionAt = now
        sessionContext = context

        let setId = context.exercises[exIdx].setContexts[setIdx].sessionSetId
        if let duration = effectiveRestDuration {
            let nudgeDuration = duration * Self.nudgeMultiplier
            await timerSystem.schedule(.nudge(setId: setId), after: nudgeDuration) { [weak self] in
                await self?.handleRestNudge(setId: setId)
            }
        }
        scheduleIdleReset(sessionId: context.sessionId)
    }

    /// Transitions the current set from resting → awaitingInput.
    func restEnded() throws {
        guard case .active = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "restEnded")
        }
        guard var context = sessionContext else { throw SessionEngineError.setNotFound }
        let exIdx = context.currentExerciseIndex
        let setIdx = context.currentSetIndex
        guard case .resting = context.exercises[exIdx].setContexts[setIdx].lifecycleState else {
            throw SessionEngineError.invalidTransition(from: state, action: "restEnded: set not resting")
        }

        let now = Date()
        context.exercises[exIdx].setContexts[setIdx].restEnd = now
        context.exercises[exIdx].setContexts[setIdx].lifecycleState = .awaitingInput
        context.lastInteractionAt = now
        sessionContext = context
        scheduleIdleReset(sessionId: context.sessionId)
    }

    /// Logs reps and weight for the current set, persists to repository.
    /// isUnrecorded = true when the set was never started (setTimerStart == nil). (Edge case 6)
    func logCurrentSet(reps: Int?, durationSeconds: TimeInterval? = nil, weight: Double?) async throws {
        guard case .active = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "logCurrentSet")
        }
        guard var context = sessionContext else { throw SessionEngineError.setNotFound }
        let exIdx = context.currentExerciseIndex
        let setIdx = context.currentSetIndex

        var set = context.exercises[exIdx].setContexts[setIdx]
        let now = Date()

        if case .inProgress = set.lifecycleState {
            set.setTimerEnd = now
        }
        if set.restStart != nil && set.restEnd == nil {
            set.restEnd = now
        }
        await timerSystem.cancel(.nudge(setId: set.sessionSetId))

        let isUnrecorded = set.setTimerStart == nil  // was never actually started
        set.reps = reps
        set.durationSeconds = durationSeconds
        set.weight = weight
        set.isUnrecorded = isUnrecorded
        set.lifecycleState = .logged(reps: reps, durationSeconds: durationSeconds, weight: weight)

        context.exercises[exIdx].setContexts[setIdx] = set
        context.lastInteractionAt = now
        sessionContext = context

        try await sessionRepository.updateSet(
            setId: set.sessionSetId,
            status: .logged,
            reps: reps,
            durationSeconds: durationSeconds,
            weight: weight,
            setTimerStart: set.setTimerStart,
            setTimerEnd: set.setTimerEnd,
            restStart: set.restStart,
            restEnd: set.restEnd,
            isUnrecorded: isUnrecorded
        )
        scheduleIdleReset(sessionId: context.sessionId)
        notifyWatch(state: state)
    }

    /// Advances to the next set, or next exercise if all sets are done.
    /// Enforces all sets are logged before crossing to a new exercise. (Edge case 2)
    func advanceToNext() async throws {
        guard case .active = state, var context = sessionContext else {
            throw SessionEngineError.invalidTransition(from: state, action: "advanceToNext")
        }
        guard let exercise = context.currentExercise else { return }

        let nextSetIndex = context.currentSetIndex + 1
        if nextSetIndex < exercise.setContexts.count {
            context.currentSetIndex = nextSetIndex
            beginCurrentSet(in: &context)
            sessionContext = context
        } else {
            // All sets done — enforce logging before moving to next exercise (edge case 2)
            let unlogged = exercise.setContexts.filter { set in
                if case .logged = set.lifecycleState { return false }
                if case .notPerformed = set.lifecycleState { return false }
                return true
            }
            guard unlogged.isEmpty else {
                throw SessionEngineError.allSetsNotLogged
            }

            context.exercises[context.currentExerciseIndex].status = .complete
            try await sessionRepository.updateExerciseStatus(
                exerciseId: exercise.sessionExerciseId,
                status: .complete
            )

            let nextExerciseIndex = context.currentExerciseIndex + 1
            if nextExerciseIndex < context.exercises.count {
                context.currentExerciseIndex = nextExerciseIndex
                context.currentSetIndex = 0
                beginCurrentSet(in: &context)
            }
            sessionContext = context
        }
        scheduleIdleReset(sessionId: context.sessionId)
        notifyWatch(state: state)
    }

    // MARK: - Navigate to previous set (Siri intent support)

    /// Moves the current set index back by one. No-op if already at first set of first exercise.
    func goToPreviousSet() throws {
        guard case .active = state, var context = sessionContext else {
            throw SessionEngineError.invalidTransition(from: state, action: "goToPreviousSet")
        }
        if context.currentSetIndex > 0 {
            context.currentSetIndex -= 1
            sessionContext = context
        } else if context.currentExerciseIndex > 0 {
            let prevExIdx = context.currentExerciseIndex - 1
            context.currentExerciseIndex = prevExIdx
            context.currentSetIndex = max(0, context.exercises[prevExIdx].setContexts.count - 1)
            sessionContext = context
        } else {
            throw SessionEngineError.invalidTransition(from: state, action: "goToPreviousSet: already at first set")
        }
    }

    // MARK: - Skip set (Siri intent support)

    /// Marks the current set as not performed, then advances to the next set or exercise.
    func skipCurrentSet() async throws {
        guard case .active = state, var context = sessionContext else {
            throw SessionEngineError.invalidTransition(from: state, action: "skipCurrentSet")
        }
        guard context.currentSet != nil else { throw SessionEngineError.setNotFound }

        let exIdx = context.currentExerciseIndex
        let setIdx = context.currentSetIndex
        var set = context.exercises[exIdx].setContexts[setIdx]
        set.lifecycleState = .notPerformed
        set.isUnrecorded = set.setTimerStart == nil
        context.exercises[exIdx].setContexts[setIdx] = set
        context.lastInteractionAt = Date()
        sessionContext = context

        await timerSystem.cancel(.nudge(setId: set.sessionSetId))
        try await sessionRepository.updateSet(
            setId: set.sessionSetId,
            status: .notPerformed,
            reps: nil,
            durationSeconds: nil,
            weight: nil,
            setTimerStart: set.setTimerStart,
            setTimerEnd: set.setTimerEnd,
            restStart: set.restStart,
            restEnd: set.restEnd,
            isUnrecorded: set.isUnrecorded
        )
        try await advanceAfterSkippingSet()
        scheduleIdleReset(sessionId: context.sessionId)
        notifyWatch(state: state)
    }

    // MARK: - Pause / Resume

    func pauseSession() async throws {
        guard case .active(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "pauseSession")
        }
        let now = Date()
        let pauseId = try await sessionRepository.addPauseRecord(sessionId: sessionId, startedAt: now)
        sessionContext?.pauseRecordId = pauseId
        await timerSystem.cancel(.idle(sessionId: sessionId))
        transition(to: .paused(sessionId: sessionId))
    }

    func resumeSession() async throws {
        guard case .paused(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "resumeSession")
        }
        let now = Date()
        if let pauseId = sessionContext?.pauseRecordId {
            try await sessionRepository.endPauseRecord(pauseId: pauseId, endedAt: now)
            sessionContext?.pauseRecordId = nil
        }
        await startIdleTimer(sessionId: sessionId)
        transition(to: .active(sessionId: sessionId))
    }

    // MARK: - End session

    /// Transitions to .ending and returns in-progress sets for review. (Edge case 3)
    func endSession() async throws -> [UnloggedSetInfo] {
        guard case .active(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "endSession")
        }
        await timerSystem.cancel(.idle(sessionId: sessionId))
        let unlogged = collectUnloggedSets()
        transition(to: .ending(sessionId: sessionId))
        return unlogged
    }

    /// Finalises the session: marks unlogged sets as notPerformed, persists, transitions to ended.
    func confirmEnd() async throws {
        guard case .ending(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "confirmEnd")
        }
        if var context = sessionContext {
            for exIndex in context.exercises.indices {
                var anyLogged = false
                for setIndex in context.exercises[exIndex].setContexts.indices {
                    var set = context.exercises[exIndex].setContexts[setIndex]
                    switch set.lifecycleState {
                    case .logged:
                        anyLogged = true
                    case .notPerformed:
                        break
                    default:
                        set.lifecycleState = .notPerformed
                        context.exercises[exIndex].setContexts[setIndex] = set
                        try await sessionRepository.updateSet(
                            setId: set.sessionSetId, status: .notPerformed,
                            reps: nil, durationSeconds: nil, weight: nil,
                            setTimerStart: set.setTimerStart, setTimerEnd: set.setTimerEnd,
                            restStart: set.restStart, restEnd: set.restEnd,
                            isUnrecorded: true
                        )
                    }
                }
                if !anyLogged {
                    context.exercises[exIndex].status = .notPerformed
                    try await sessionRepository.updateExerciseStatus(
                        exerciseId: context.exercises[exIndex].sessionExerciseId,
                        status: .notPerformed
                    )
                }
            }
            sessionContext = context
        }

        let endedAt = Date()
        try await sessionRepository.updateStatus(sessionId: sessionId, status: .complete, endedAt: endedAt)

        if let healthKitService {
            if let hkId = try? await healthKitService.endWorkout(sessionId: sessionId, endDate: endedAt) {
                try? await sessionRepository.updateHealthKitWorkoutId(sessionId: sessionId, workoutId: hkId)
            }
        }

        if let iCloudService,
           let dto = try await sessionRepository.fetchById(sessionId) {
            let model = SessionExportModel.make(from: dto)
            do {
                _ = try await iCloudService.exportSession(model, templateSlug: nil)
            } catch {
                PendingExportQueue.shared.add(sessionId: sessionId)
            }
        }

        // Capture summary stats for watch end screen before clearing context
        if let context = sessionContext {
            let elapsed = endedAt.timeIntervalSince(context.sessionStartedAt) - context.totalPauseDuration
            lastEndedDurationSeconds = max(0, elapsed)
            lastEndedVolumeKg = context.exercises.flatMap(\.setContexts).compactMap { set -> Double? in
                guard case .logged(let reps, _, let weight) = set.lifecycleState,
                      let w = weight, let r = reps, r > 0 else { return nil }
                return w * Double(r)
            }.reduce(0, +)
        }

        await timerSystem.cancelAll()
        transition(to: .ended(sessionId: sessionId))
    }

    func cancelEnd() throws {
        guard case .ending(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "cancelEnd")
        }
        scheduleIdleReset(sessionId: sessionId)
        transition(to: .active(sessionId: sessionId))
    }

    /// Discards the session from .ending state — marks as incomplete and returns to idle.
    func discardSession() async throws {
        guard case .ending(let sessionId) = state else {
            throw SessionEngineError.invalidTransition(from: state, action: "discardSession")
        }
        try await sessionRepository.updateStatus(sessionId: sessionId, status: .incomplete, endedAt: Date())
        await timerSystem.cancelAll()
        sessionContext = nil
        transition(to: .idle)
    }

    // MARK: - Unplanned exercise (edge case 7: requires >= 1 set)

    func addUnplannedExercise(
        exerciseId: UUID,
        exerciseName: String = "",
        setCount: Int,
        defaultLoggingType: SetLoggingType = .reps
    ) async throws {
        let sets = (0..<setCount).map { _ in CreateTemplateSetInput(targetReps: 10, restDuration: 30) }
        try await addUnplannedExercise(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            sets: sets,
            defaultLoggingType: defaultLoggingType
        )
    }

    /// Adds an exercise to the active workout using the same set-plan shape as template editing.
    func addUnplannedExercise(
        exerciseId: UUID,
        exerciseName: String = "",
        sets: [CreateTemplateSetInput],
        defaultLoggingType: SetLoggingType = .reps
    ) async throws {
        guard case .active(let sessionId) = state, var context = sessionContext else {
            throw SessionEngineError.invalidTransition(from: state, action: "addUnplannedExercise")
        }
        guard !sets.isEmpty else {
            throw SessionEngineError.invalidTransition(
                from: state,
                action: "addUnplannedExercise: setCount must be >= 1"
            )
        }
        let order = context.exercises.count
        let sessionExerciseId = try await sessionRepository.addExercise(
            to: sessionId, exerciseId: exerciseId, order: order, executionOrder: order
        )
        var setContexts: [ActiveSessionContext.ExerciseContext.SetContext] = []
        for (index, setInput) in sets.enumerated() {
            let setId = try await sessionRepository.addSet(to: sessionExerciseId, order: index)
            setContexts.append(.init(
                sessionSetId: setId,
                order: index,
                targetReps: setInput.targetReps,
                targetDuration: setInput.targetDuration,
                targetWeight: setInput.targetWeight,
                targetRestDuration: setInput.restDuration
            ))
        }
        if let templateId = context.templateId {
            try await templateRepository.appendExercise(
                templateId: templateId,
                exercise: CreateTemplateExerciseInput(exerciseId: exerciseId, sets: sets)
            )
        }
        let shouldFocusNewExercise = context.exercises.isEmpty || context.exercises.allSatisfy { exercise in
            exercise.setContexts.allSatisfy { set in
                if case .logged = set.lifecycleState { return true }
                if case .notPerformed = set.lifecycleState { return true }
                return false
            }
        }
        context.exercises.append(ActiveSessionContext.ExerciseContext(
            sessionExerciseId: sessionExerciseId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            defaultLoggingType: defaultLoggingType,
            setContexts: setContexts
        ))
        if shouldFocusNewExercise {
            context.currentExerciseIndex = order
            context.currentSetIndex = 0
            beginCurrentSet(in: &context)
        }
        sessionContext = context
        scheduleIdleReset(sessionId: sessionId)
    }

    // MARK: - Skip exercise (edge case 8: marks notPerformed)

    func skipCurrentExercise() async throws {
        guard case .active = state, var context = sessionContext else {
            throw SessionEngineError.invalidTransition(from: state, action: "skipCurrentExercise")
        }
        guard let exercise = context.currentExercise else { return }

        for setIndex in exercise.setContexts.indices {
            let set = exercise.setContexts[setIndex]
            context.exercises[context.currentExerciseIndex].setContexts[setIndex].lifecycleState = .notPerformed
            try await sessionRepository.updateSet(
                setId: set.sessionSetId, status: .notPerformed,
                reps: nil, durationSeconds: nil, weight: nil,
                setTimerStart: nil, setTimerEnd: nil,
                restStart: nil, restEnd: nil,
                isUnrecorded: true
            )
        }

        context.exercises[context.currentExerciseIndex].status = .notPerformed
        try await sessionRepository.updateExerciseStatus(
            exerciseId: exercise.sessionExerciseId, status: .notPerformed
        )

        let nextIndex = context.currentExerciseIndex + 1
        if nextIndex < context.exercises.count {
            context.currentExerciseIndex = nextIndex
            context.currentSetIndex = 0
        }
        sessionContext = context
        scheduleIdleReset(sessionId: context.sessionId)
    }

    // MARK: - Reorder exercises mid-session (pending only, does not affect template)

    func reorderExercises(from source: IndexSet, to destination: Int) {
        guard case .active = state else { return }
        guard var context = sessionContext else { return }

        // Only move exercises where no set has been started yet
        let canMove = source.allSatisfy { index in
            index < context.exercises.count &&
            context.exercises[index].setContexts.allSatisfy { set in
                if case .pending = set.lifecycleState { return true }
                return false
            }
        }
        guard canMove else { return }
        // Don't move the currently active exercise
        guard !source.contains(context.currentExerciseIndex) else { return }

        context.exercises.move(fromOffsets: source, toOffset: destination)
        sessionContext = context
    }

    // MARK: - Reset

    func reset() async {
        await timerSystem.cancelAll()
        sessionContext = nil
        selectedTemplateId = nil
        transition(to: .idle)
    }

    // MARK: - Timer event handlers

    func handleRestNudge(setId: UUID) {
        guard case .active = state, let context = sessionContext else { return }
        // Only fire if this is still the current set (user may have already advanced)
        let current = context.exercises[context.currentExerciseIndex]
            .setContexts[context.currentSetIndex]
        guard current.sessionSetId == setId else { return }
        notifyWatchReminder()
    }

    private func notifyWatchReminder() {
        guard let watchSyncService else { return }
        let context = sessionContext
        let currentState = state
        Task { [weak self] in
            guard let self else { return }
            var message = await self.buildWatchMessage(for: currentState, context: context)
            message.reminderFired = true
            await watchSyncService.sendSessionState(message)
        }
    }

    func handleIdleTimeout() async {
        guard case .active = state else { return }
        _ = try? await endSession()
        try? await confirmEnd()
    }

    func handleMaxTimer() async {
        await handleIdleTimeout()
    }

    private func advanceAfterSkippingSet() async throws {
        guard var context = sessionContext else { throw SessionEngineError.setNotFound }
        let exercise = context.exercises[context.currentExerciseIndex]
        let nextSetIndex = context.currentSetIndex + 1

        if nextSetIndex < exercise.setContexts.count {
            context.currentSetIndex = nextSetIndex
            sessionContext = context
            return
        }

        let finished = exercise.setContexts.allSatisfy { set in
            if case .logged = set.lifecycleState { return true }
            if case .notPerformed = set.lifecycleState { return true }
            return false
        }
        if finished {
            context.exercises[context.currentExerciseIndex].status = .complete
            try await sessionRepository.updateExerciseStatus(
                exerciseId: exercise.sessionExerciseId,
                status: .complete
            )
        }

        let nextExerciseIndex = context.currentExerciseIndex + 1
        if nextExerciseIndex < context.exercises.count {
            context.currentExerciseIndex = nextExerciseIndex
            context.currentSetIndex = 0
        }
        sessionContext = context
    }

    // MARK: - Private: timer management

    private func startTimers(sessionId: UUID) async {
        await timerSystem.schedule(.sessionMax(sessionId: sessionId), after: Self.maxSessionDuration) { [weak self] in
            await self?.handleMaxTimer()
        }
        await startIdleTimer(sessionId: sessionId)
    }

    private func startIdleTimer(sessionId: UUID) async {
        await timerSystem.schedule(.idle(sessionId: sessionId), after: Self.idleAutoEndDuration) { [weak self] in
            await self?.handleIdleTimeout()
        }
    }

    /// Reschedules the idle timer without blocking the caller. Fire-and-forget.
    private func scheduleIdleReset(sessionId: UUID) {
        Task { [weak self] in
            guard let self else { return }
            await self.timerSystem.cancel(.idle(sessionId: sessionId))
            await self.timerSystem.schedule(
                .idle(sessionId: sessionId),
                after: Self.idleAutoEndDuration
            ) { [weak self] in
                await self?.handleIdleTimeout()
            }
        }
    }

    // MARK: - Private: state helpers

    private func transition(to newState: SessionEngineState) {
        state = newState
        stateUpdatesContinuation.yield(newState)
        notifyWatch(state: newState)
    }

    private func notifyWatch(state: SessionEngineState) {
        guard let watchSyncService else { return }
        let context = sessionContext
        Task { [weak self] in
            guard let self else { return }
            let message = await self.buildWatchMessage(for: state, context: context)
            await watchSyncService.sendSessionState(message)
        }
    }

    private func buildWatchMessage(
        for state: SessionEngineState,
        context: ActiveSessionContext?
    ) -> WatchSessionStateMessage {
        let stateName: String
        switch state {
        case .idle: stateName = "idle"
        case .templateSelected: stateName = "templateSelected"
        case .active: stateName = "active"
        case .paused: stateName = "paused"
        case .ending: stateName = "ending"
        case .ended: stateName = "ended"
        }

        let isDetailedState: Bool
        switch state {
        case .active, .paused: isDetailedState = true
        default: isDetailedState = false
        }
        guard isDetailedState, let context else {
            // Include summary stats on "ended" so watch can show duration/volume
            var endedDuration: TimeInterval? = nil
            var endedVolume: Double? = nil
            if case .ended = state {
                endedDuration = lastEndedDurationSeconds > 0 ? lastEndedDurationSeconds : nil
                endedVolume = lastEndedVolumeKg
            }
            return WatchSessionStateMessage(
                sessionId: context?.sessionId.uuidString ?? "",
                engineState: stateName,
                exerciseName: nil, setNumber: nil, totalSets: nil, setStatus: nil,
                targetReps: nil, targetDuration: nil, targetWeight: nil,
                loggingType: nil, unitSystem: unitSystem,
                reminderFired: nil,
                sessionDurationSeconds: endedDuration,
                sessionVolumeKg: endedVolume
            )
        }

        let exercise = context.currentExercise
        let set = context.currentSet
        let setStatusName: String?
        if let set {
            switch set.lifecycleState {
            case .pending: setStatusName = "pending"
            case .inProgress: setStatusName = "inProgress"
            case .resting: setStatusName = "resting"
            case .awaitingInput: setStatusName = "awaitingInput"
            case .logged: setStatusName = "logged"
            case .notPerformed: setStatusName = "notPerformed"
            }
        } else {
            setStatusName = nil
        }

        let loggingType = exercise.map { ex in
            ex.defaultLoggingType == .duration ? "duration" : "reps"
        }

        return WatchSessionStateMessage(
            sessionId: context.sessionId.uuidString,
            engineState: stateName,
            exerciseName: exercise?.exerciseName,
            setNumber: context.currentSetIndex + 1,
            totalSets: exercise?.setContexts.count,
            setStatus: setStatusName,
            targetReps: set?.targetReps,
            targetDuration: set?.targetDuration,
            targetWeight: set?.targetWeight,
            loggingType: loggingType,
            unitSystem: unitSystem,
            reminderFired: nil,
            sessionDurationSeconds: nil,
            sessionVolumeKg: nil
        )
    }

    private func collectUnloggedSets() -> [UnloggedSetInfo] {
        guard let context = sessionContext else { return [] }
        var result: [UnloggedSetInfo] = []
        for exercise in context.exercises {
            for set in exercise.setContexts {
                switch set.lifecycleState {
                case .inProgress, .resting, .awaitingInput:
                    result.append(UnloggedSetInfo(
                        setId: set.sessionSetId,
                        exerciseId: exercise.exerciseId,
                        setOrder: set.order
                    ))
                case .pending, .logged, .notPerformed:
                    break
                }
            }
        }
        return result
    }

    private func beginCurrentSet(in context: inout ActiveSessionContext, startedAt: Date = Date()) {
        guard context.currentExerciseIndex < context.exercises.count else { return }
        let exIdx = context.currentExerciseIndex
        guard context.currentSetIndex < context.exercises[exIdx].setContexts.count else { return }
        guard case .pending = context.exercises[exIdx].setContexts[context.currentSetIndex].lifecycleState else {
            return
        }
        context.exercises[exIdx].setContexts[context.currentSetIndex].setTimerStart = startedAt
        context.exercises[exIdx].setContexts[context.currentSetIndex].lifecycleState = .inProgress(startedAt: startedAt)
        context.exercises[exIdx].status = .inProgress
        context.lastInteractionAt = startedAt
    }

    private func clearEndedSessionIfNeeded() {
        if case .ended = state {
            selectedTemplateId = nil
            sessionContext = nil
            transition(to: .idle)
        }
    }
}
