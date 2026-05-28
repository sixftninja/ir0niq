import Foundation

// MARK: - Exercise DTO

struct ExerciseDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let exerciseDescription: String
    let equipmentType: EquipmentType
    let isSingleHand: Bool
    let muscleGroups: [MuscleGroup]
    let iconName: String
    let isCustom: Bool
    let isSeeded: Bool

    init(
        id: UUID = UUID(),
        name: String,
        exerciseDescription: String,
        equipmentType: EquipmentType,
        isSingleHand: Bool,
        muscleGroups: [MuscleGroup],
        iconName: String,
        isCustom: Bool = false,
        isSeeded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.equipmentType = equipmentType
        self.isSingleHand = isSingleHand
        self.muscleGroups = muscleGroups
        self.iconName = iconName
        self.isCustom = isCustom
        self.isSeeded = isSeeded
    }

    init(from model: Exercise) {
        self.id = model.id
        self.name = model.name
        self.exerciseDescription = model.exerciseDescription
        self.equipmentType = model.equipmentTypeEnum
        self.isSingleHand = model.isSingleHand
        self.muscleGroups = model.muscleGroups
        self.iconName = model.iconName
        self.isCustom = model.isCustom
        self.isSeeded = model.isSeeded
    }
}

// MARK: - Template DTOs

struct TemplateDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let exercises: [TemplateExerciseDTO]
}

struct TemplateExerciseDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let order: Int
    let equipmentTypeOverride: EquipmentType?
    let sets: [TemplateSetDTO]
}

struct TemplateSetDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let order: Int
    let targetReps: Int?
    let targetWeight: Double?
    let targetDuration: TimeInterval?
    let restDuration: TimeInterval?
    let noteLabel: String?

    init(
        id: UUID = UUID(),
        order: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        targetDuration: TimeInterval? = nil,
        restDuration: TimeInterval? = nil,
        noteLabel: String? = nil
    ) {
        self.id = id
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetDuration = targetDuration
        self.restDuration = restDuration
        self.noteLabel = noteLabel
    }

    init(from model: TemplateSet) {
        self.id = model.id
        self.order = model.order
        self.targetReps = model.targetReps
        self.targetWeight = model.targetWeight
        self.targetDuration = model.targetDuration
        self.restDuration = model.restDuration
        self.noteLabel = model.noteLabel
    }
}

// MARK: - Session DTOs

struct SessionDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let templateId: UUID?
    let startedAt: Date
    let endedAt: Date?
    let status: SessionStatus
    let totalPauseDuration: TimeInterval
    let exercises: [SessionExerciseDTO]
}

struct SessionExerciseDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let order: Int
    let executionOrder: Int
    let status: SessionExerciseStatus
    let sets: [SessionSetDTO]
}

struct SessionSetDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let order: Int
    let status: SetStatus
    let reps: Int?
    let weight: Double?
    let setTimerStart: Date?
    let setTimerEnd: Date?
    let restStart: Date?
    let restEnd: Date?
    let noteLabel: String?
    let isUnrecorded: Bool

    init(
        id: UUID = UUID(),
        order: Int,
        status: SetStatus = .pending,
        reps: Int? = nil,
        weight: Double? = nil,
        setTimerStart: Date? = nil,
        setTimerEnd: Date? = nil,
        restStart: Date? = nil,
        restEnd: Date? = nil,
        noteLabel: String? = nil,
        isUnrecorded: Bool = false
    ) {
        self.id = id
        self.order = order
        self.status = status
        self.reps = reps
        self.weight = weight
        self.setTimerStart = setTimerStart
        self.setTimerEnd = setTimerEnd
        self.restStart = restStart
        self.restEnd = restEnd
        self.noteLabel = noteLabel
        self.isUnrecorded = isUnrecorded
    }

    init(from model: SessionSet) {
        self.id = model.id
        self.order = model.order
        self.status = model.status
        self.reps = model.reps
        self.weight = model.weight
        self.setTimerStart = model.setTimerStart
        self.setTimerEnd = model.setTimerEnd
        self.restStart = model.restStart
        self.restEnd = model.restEnd
        self.noteLabel = model.noteLabel
        self.isUnrecorded = model.isUnrecorded
    }
}
