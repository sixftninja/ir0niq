import Foundation

// MARK: - Equipment

enum EquipmentType: String, Codable, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case resistanceBand
    case other

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .resistanceBand: return "Resistance Band"
        case .other: return "Other"
        }
    }
}

// MARK: - Muscle Groups

enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case quadriceps
    case hamstrings
    case glutes
    case calves
    case core
    case fullBody

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .quadriceps: return "Quadriceps"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        }
    }
}

// MARK: - Session Status

enum SessionStatus: String, Codable, Sendable {
    case complete
    case incomplete
    case notPerformed
}

// MARK: - Session Exercise Status

enum SessionExerciseStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case complete
    case notPerformed
}

// MARK: - Set Status

enum SetStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case resting
    case awaitingInput
    case logged
    case notPerformed
}

// MARK: - Session Engine State

enum SessionEngineState: Equatable, Sendable {
    case idle
    case templateSelected(templateId: UUID)
    case active(sessionId: UUID)
    case paused(sessionId: UUID)
    case ending(sessionId: UUID)
    case ended(sessionId: UUID)
}

// MARK: - Timer Types

enum TimerKind: Hashable, Sendable {
    case set(setId: UUID)
    case rest(setId: UUID)
    case betweenExercise(exerciseId: UUID)
    case session(sessionId: UUID)
    case sessionMax(sessionId: UUID)
    case nudge(setId: UUID)
    case idle(sessionId: UUID)
}

// MARK: - Session Engine Error

enum SessionEngineError: Error, Equatable, Sendable {
    case invalidTransition(from: SessionEngineState, action: String)
    case sessionNotFound
    case exerciseNotFound
    case setNotFound
    case allSetsNotLogged
    case templateNotFound
}

// MARK: - Unit System

enum UnitSystem: String, Codable, Sendable {
    case imperial
    case metric
}
