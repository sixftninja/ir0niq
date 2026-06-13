import Foundation
import SwiftData

// MARK: - Protocol

protocol SessionRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [SessionDTO]
    func fetchById(_ id: UUID) async throws -> SessionDTO?
    func createSession(templateId: UUID?, startedAt: Date) async throws -> UUID
    func updateStatus(sessionId: UUID, status: SessionStatus, endedAt: Date?) async throws
    func updateTotalPauseDuration(sessionId: UUID, duration: TimeInterval) async throws
    func addExercise(
        to sessionId: UUID,
        exerciseId: UUID,
        order: Int,
        executionOrder: Int
    ) async throws -> UUID
    func addSet(to sessionExerciseId: UUID, order: Int) async throws -> UUID
    func updateSet(
        setId: UUID,
        status: SetStatus,
        reps: Int?,
        durationSeconds: TimeInterval?,
        weight: Double?,
        setTimerStart: Date?,
        setTimerEnd: Date?,
        restStart: Date?,
        restEnd: Date?,
        isUnrecorded: Bool
    ) async throws
    func updateExerciseStatus(exerciseId: UUID, status: SessionExerciseStatus) async throws
    func addPauseRecord(sessionId: UUID, startedAt: Date) async throws -> UUID
    func endPauseRecord(pauseId: UUID, endedAt: Date) async throws
    func updateHealthKitWorkoutId(sessionId: UUID, workoutId: UUID) async throws
    func delete(sessionId: UUID) async throws
    func count() async throws -> Int
}

// MARK: - DTO construction helpers

private func makeSessionDTO(from model: Session) -> SessionDTO {
    let exerciseDTOs = model.exercises
        .sorted { $0.order < $1.order }
        .map { makeSessionExerciseDTO(from: $0) }
    return SessionDTO(
        id: model.id,
        templateId: model.template?.id,
        templateName: model.template?.name,
        isFromArchivedTemplate: model.template?.isArchived ?? false,
        startedAt: model.startedAt,
        endedAt: model.endedAt,
        status: model.status,
        totalPauseDuration: model.totalPauseDuration,
        exercises: exerciseDTOs
    )
}

private func makeSessionExerciseDTO(from model: SessionExercise) -> SessionExerciseDTO {
    let setDTOs = model.sets
        .sorted { $0.order < $1.order }
        .map { SessionSetDTO(from: $0) }
    return SessionExerciseDTO(
        id: model.id,
        exerciseId: model.exercise?.id ?? UUID(),
        exerciseName: model.exercise?.name ?? "",
        order: model.order,
        executionOrder: model.executionOrder,
        status: model.status,
        sets: setDTOs
    )
}

// MARK: - Implementation

@ModelActor
actor SessionRepository: SessionRepositoryProtocol {

    func fetchAll() throws -> [SessionDTO] {
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map { makeSessionDTO(from: $0) }
    }

    func fetchById(_ id: UUID) throws -> SessionDTO? {
        let predicate = #Predicate<Session> { $0.id == id }
        var descriptor = FetchDescriptor<Session>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map { makeSessionDTO(from: $0) }
    }

    func createSession(templateId: UUID?, startedAt: Date) throws -> UUID {
        let template: Template? = try {
            guard let tid = templateId else { return nil }
            let predicate = #Predicate<Template> { $0.id == tid }
            var descriptor = FetchDescriptor<Template>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        }()

        let session = Session(template: template, startedAt: startedAt)
        modelContext.insert(session)
        try modelContext.save()
        return session.id
    }

    func updateStatus(sessionId: UUID, status: SessionStatus, endedAt: Date?) throws {
        guard let session = try fetchSessionModel(id: sessionId) else { return }
        session.status = status
        session.endedAt = endedAt
        if let endedAt, let startedAt = Optional(session.startedAt) {
            session.actualDuration = endedAt.timeIntervalSince(startedAt) - session.totalPauseDuration
        }
        try modelContext.save()
    }

    func updateTotalPauseDuration(sessionId: UUID, duration: TimeInterval) throws {
        guard let session = try fetchSessionModel(id: sessionId) else { return }
        session.totalPauseDuration = duration
        try modelContext.save()
    }

    func addExercise(
        to sessionId: UUID,
        exerciseId: UUID,
        order: Int,
        executionOrder: Int
    ) throws -> UUID {
        guard let session = try fetchSessionModel(id: sessionId) else {
            throw SessionRepositoryError.sessionNotFound
        }

        let exercisePredicate = #Predicate<Exercise> { $0.id == exerciseId }
        var exerciseDescriptor = FetchDescriptor<Exercise>(predicate: exercisePredicate)
        exerciseDescriptor.fetchLimit = 1
        guard let exercise = try modelContext.fetch(exerciseDescriptor).first else {
            throw SessionRepositoryError.exerciseNotFound
        }

        let sessionExercise = SessionExercise(
            exercise: exercise,
            order: order,
            executionOrder: executionOrder
        )
        sessionExercise.session = session
        modelContext.insert(sessionExercise)
        try modelContext.save()
        return sessionExercise.id
    }

    func addSet(to sessionExerciseId: UUID, order: Int) throws -> UUID {
        let predicate = #Predicate<SessionExercise> { $0.id == sessionExerciseId }
        var descriptor = FetchDescriptor<SessionExercise>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let sessionExercise = try modelContext.fetch(descriptor).first else {
            throw SessionRepositoryError.exerciseNotFound
        }

        let sessionSet = SessionSet(order: order)
        sessionSet.sessionExercise = sessionExercise
        modelContext.insert(sessionSet)
        try modelContext.save()
        return sessionSet.id
    }

    func updateSet(
        setId: UUID,
        status: SetStatus,
        reps: Int?,
        durationSeconds: TimeInterval?,
        weight: Double?,
        setTimerStart: Date?,
        setTimerEnd: Date?,
        restStart: Date?,
        restEnd: Date?,
        isUnrecorded: Bool
    ) throws {
        guard let set = try fetchSetModel(id: setId) else { return }
        set.status = status
        set.reps = reps
        set.durationSeconds = durationSeconds
        set.weight = weight
        set.setTimerStart = setTimerStart
        set.setTimerEnd = setTimerEnd
        set.restStart = restStart
        set.restEnd = restEnd
        set.isUnrecorded = isUnrecorded
        try modelContext.save()
    }

    func updateExerciseStatus(exerciseId: UUID, status: SessionExerciseStatus) throws {
        let predicate = #Predicate<SessionExercise> { $0.id == exerciseId }
        var descriptor = FetchDescriptor<SessionExercise>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let model = try modelContext.fetch(descriptor).first {
            model.status = status
            try modelContext.save()
        }
    }

    func addPauseRecord(sessionId: UUID, startedAt: Date) throws -> UUID {
        guard let session = try fetchSessionModel(id: sessionId) else {
            throw SessionRepositoryError.sessionNotFound
        }
        let record = PauseRecord(session: session, startedAt: startedAt)
        modelContext.insert(record)
        try modelContext.save()
        return record.id
    }

    func endPauseRecord(pauseId: UUID, endedAt: Date) throws {
        let predicate = #Predicate<PauseRecord> { $0.id == pauseId }
        var descriptor = FetchDescriptor<PauseRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let record = try modelContext.fetch(descriptor).first {
            record.endedAt = endedAt
            try modelContext.save()
        }
    }

    func updateHealthKitWorkoutId(sessionId: UUID, workoutId: UUID) throws {
        guard let session = try fetchSessionModel(id: sessionId) else { return }
        session.healthKitWorkoutId = workoutId
        try modelContext.save()
    }

    func delete(sessionId: UUID) throws {
        guard let session = try fetchSessionModel(id: sessionId) else { return }
        modelContext.delete(session)
        try modelContext.save()
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Session>())
    }

    // MARK: - Private helpers

    private func fetchSessionModel(id: UUID) throws -> Session? {
        let predicate = #Predicate<Session> { $0.id == id }
        var descriptor = FetchDescriptor<Session>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchSetModel(id: UUID) throws -> SessionSet? {
        let predicate = #Predicate<SessionSet> { $0.id == id }
        var descriptor = FetchDescriptor<SessionSet>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

// MARK: - Errors

enum SessionRepositoryError: Error, Equatable {
    case sessionNotFound
    case exerciseNotFound
    case setNotFound
}
