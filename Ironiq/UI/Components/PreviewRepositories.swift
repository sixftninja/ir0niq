import Foundation

/// Thin in-memory stubs used only in SwiftUI #Preview macros.
enum PreviewRepositories {
    static let template = PreviewTemplateRepository()
    static let session  = PreviewSessionRepository()
    static let exercise = PreviewExerciseRepository()
}

final class PreviewTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [TemplateDTO] { [] }
    func fetchById(_ id: UUID) async throws -> TemplateDTO? { nil }
    func insert(name: String, exercises: [CreateTemplateExerciseInput]) async throws -> UUID { UUID() }
    func update(id: UUID, name: String, exercises: [CreateTemplateExerciseInput]) async throws {}
    func delete(id: UUID) async throws {}
    func appendExercise(templateId: UUID, exercise: CreateTemplateExerciseInput) async throws {}
    func count() async throws -> Int { 0 }
}

final class PreviewSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [SessionDTO] { [] }
    func fetchById(_ id: UUID) async throws -> SessionDTO? { nil }
    func createSession(templateId: UUID?, startedAt: Date) async throws -> UUID { UUID() }
    func updateStatus(sessionId: UUID, status: SessionStatus, endedAt: Date?) async throws {}
    func updateTotalPauseDuration(sessionId: UUID, duration: TimeInterval) async throws {}
    func addExercise(to sessionId: UUID, exerciseId: UUID, order: Int, executionOrder: Int) async throws -> UUID { UUID() }
    func addSet(to sessionExerciseId: UUID, order: Int) async throws -> UUID { UUID() }
    func updateSet(setId: UUID, status: SetStatus, reps: Int?, durationSeconds: TimeInterval?, weight: Double?, setTimerStart: Date?, setTimerEnd: Date?, restStart: Date?, restEnd: Date?, isUnrecorded: Bool) async throws {}
    func updateExerciseStatus(exerciseId: UUID, status: SessionExerciseStatus) async throws {}
    func addPauseRecord(sessionId: UUID, startedAt: Date) async throws -> UUID { UUID() }
    func endPauseRecord(pauseId: UUID, endedAt: Date) async throws {}
    func updateHealthKitWorkoutId(sessionId: UUID, workoutId: UUID) async throws {}
    func delete(sessionId: UUID) async throws {}
    func count() async throws -> Int { 0 }
}

final class PreviewExerciseRepository: ExerciseRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [ExerciseDTO] { [] }
    func fetchById(_ id: UUID) async throws -> ExerciseDTO? { nil }
    func insert(id: UUID, name: String, exerciseDescription: String, equipmentType: EquipmentType, isSingleHand: Bool, muscleGroups: [MuscleGroup], iconName: String, isCustom: Bool, isSeeded: Bool, defaultLoggingType: SetLoggingType) async throws -> UUID { UUID() }
    func delete(id: UUID) async throws {}
    func seedIfNeeded(exercises: [SeedExerciseData]) async throws -> Int { 0 }
    func count() async throws -> Int { 0 }
}
