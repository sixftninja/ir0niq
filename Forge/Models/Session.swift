import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var template: Template?
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    var plannedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var totalPauseDuration: TimeInterval
    var healthKitWorkoutId: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]
    @Relationship(deleteRule: .cascade, inverse: \PauseRecord.session)
    var pauseRecords: [PauseRecord]

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .incomplete }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        template: Template? = nil,
        startedAt: Date = Date(),
        status: SessionStatus = .incomplete,
        plannedDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.template = template
        self.startedAt = startedAt
        self.statusRaw = status.rawValue
        self.plannedDuration = plannedDuration
        self.totalPauseDuration = 0
        self.exercises = []
        self.pauseRecords = []
    }
}

@Model
final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var session: Session?
    var exercise: Exercise?
    var order: Int
    var executionOrder: Int
    var statusRaw: String
    var betweenExerciseRestStart: Date?
    var betweenExerciseRestEnd: Date?
    @Relationship(deleteRule: .cascade, inverse: \SessionSet.sessionExercise)
    var sets: [SessionSet]

    var status: SessionExerciseStatus {
        get { SessionExerciseStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        order: Int,
        executionOrder: Int,
        status: SessionExerciseStatus = .pending
    ) {
        self.id = id
        self.exercise = exercise
        self.order = order
        self.executionOrder = executionOrder
        self.statusRaw = status.rawValue
        self.sets = []
    }
}

@Model
final class SessionSet {
    @Attribute(.unique) var id: UUID
    var sessionExercise: SessionExercise?
    var order: Int
    var statusRaw: String
    var reps: Int?
    var weight: Double?
    var setTimerStart: Date?
    var setTimerEnd: Date?
    var restStart: Date?
    var restEnd: Date?
    var noteLabel: String?
    var isUnrecorded: Bool

    var status: SetStatus {
        get { SetStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var setDuration: TimeInterval? {
        guard let start = setTimerStart, let end = setTimerEnd else { return nil }
        return end.timeIntervalSince(start)
    }

    var restDuration: TimeInterval? {
        guard let start = restStart, let end = restEnd else { return nil }
        return end.timeIntervalSince(start)
    }

    init(
        id: UUID = UUID(),
        order: Int,
        status: SetStatus = .pending,
        isUnrecorded: Bool = false
    ) {
        self.id = id
        self.order = order
        self.statusRaw = status.rawValue
        self.isUnrecorded = isUnrecorded
    }
}

@Model
final class PauseRecord {
    @Attribute(.unique) var id: UUID
    var session: Session?
    var startedAt: Date
    var endedAt: Date?

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    init(
        id: UUID = UUID(),
        session: Session? = nil,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.session = session
        self.startedAt = startedAt
    }
}
