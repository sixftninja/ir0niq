import Foundation
@testable import Forge

// MARK: - MockTemplateRepository

actor MockTemplateRepository: TemplateRepositoryProtocol {
    var templates: [TemplateDTO] = []

    func fetchAll() throws -> [TemplateDTO] { templates }

    func fetchById(_ id: UUID) throws -> TemplateDTO? {
        templates.first { $0.id == id }
    }

    func insert(name: String, exercises: [CreateTemplateExerciseInput]) throws -> UUID {
        let id = UUID()
        templates.append(TemplateDTO(id: id, name: name, createdAt: Date(), exercises: []))
        return id
    }

    func delete(id: UUID) throws {
        templates.removeAll { $0.id == id }
    }

    func count() throws -> Int { templates.count }

    /// Test helper to pre-seed a template.
    func seed(template: TemplateDTO) { templates.append(template) }
}

// MARK: - MockSessionRepository

actor MockSessionRepository: SessionRepositoryProtocol {
    struct SessionRecord {
        var id: UUID
        var status: SessionStatus
        var endedAt: Date?
    }

    struct SetRecord {
        var status: SetStatus
        var reps: Int?
        var weight: Double?
        var isUnrecorded: Bool
        var setTimerStart: Date?
        var setTimerEnd: Date?
        var restStart: Date?
        var restEnd: Date?
    }

    var sessions: [UUID: SessionRecord] = [:]
    var sessionExercises: [UUID: (sessionId: UUID, exerciseId: UUID)] = [:]
    var sessionSets: [UUID: SetRecord] = [:]
    var pauseRecords: [UUID: (sessionId: UUID, endedAt: Date?)] = [:]
    var exerciseStatusUpdates: [UUID: SessionExerciseStatus] = [:]

    func fetchAll() throws -> [SessionDTO] { [] }
    func fetchById(_ id: UUID) throws -> SessionDTO? { nil }

    func createSession(templateId: UUID?, startedAt: Date) throws -> UUID {
        let id = UUID()
        sessions[id] = SessionRecord(id: id, status: .incomplete, endedAt: nil)
        return id
    }

    func updateStatus(sessionId: UUID, status: SessionStatus, endedAt: Date?) throws {
        sessions[sessionId] = SessionRecord(id: sessionId, status: status, endedAt: endedAt)
    }

    func updateTotalPauseDuration(sessionId: UUID, duration: TimeInterval) throws {}

    func addExercise(to sessionId: UUID, exerciseId: UUID, order: Int, executionOrder: Int) throws -> UUID {
        let id = UUID()
        sessionExercises[id] = (sessionId: sessionId, exerciseId: exerciseId)
        return id
    }

    func addSet(to sessionExerciseId: UUID, order: Int) throws -> UUID {
        let id = UUID()
        sessionSets[id] = SetRecord(status: .pending, isUnrecorded: false)
        return id
    }

    func updateSet(
        setId: UUID,
        status: SetStatus,
        reps: Int?,
        weight: Double?,
        setTimerStart: Date?,
        setTimerEnd: Date?,
        restStart: Date?,
        restEnd: Date?,
        isUnrecorded: Bool
    ) throws {
        sessionSets[setId] = SetRecord(
            status: status,
            reps: reps,
            weight: weight,
            isUnrecorded: isUnrecorded,
            setTimerStart: setTimerStart,
            setTimerEnd: setTimerEnd,
            restStart: restStart,
            restEnd: restEnd
        )
    }

    func updateExerciseStatus(exerciseId: UUID, status: SessionExerciseStatus) throws {
        exerciseStatusUpdates[exerciseId] = status
    }

    func addPauseRecord(sessionId: UUID, startedAt: Date) throws -> UUID {
        let id = UUID()
        pauseRecords[id] = (sessionId: sessionId, endedAt: nil)
        return id
    }

    func endPauseRecord(pauseId: UUID, endedAt: Date) throws {
        if var record = pauseRecords[pauseId] {
            record.endedAt = endedAt
            pauseRecords[pauseId] = record
        }
    }

    func delete(sessionId: UUID) throws {
        sessions.removeValue(forKey: sessionId)
    }

    func count() throws -> Int { sessions.count }

    // Test helpers
    func sessionStatus(for id: UUID) -> SessionStatus? { sessions[id]?.status }
    func setRecord(for id: UUID) -> SetRecord? { sessionSets[id] }
}
