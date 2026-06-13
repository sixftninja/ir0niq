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
    let defaultLoggingType: SetLoggingType

    init(
        id: UUID = UUID(),
        name: String,
        exerciseDescription: String,
        equipmentType: EquipmentType,
        isSingleHand: Bool,
        muscleGroups: [MuscleGroup],
        iconName: String,
        isCustom: Bool = false,
        isSeeded: Bool = false,
        defaultLoggingType: SetLoggingType = .reps
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
        self.defaultLoggingType = defaultLoggingType
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
        self.defaultLoggingType = model.defaultLoggingType
    }
}

// MARK: - Template DTOs

struct TemplateDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let exercises: [TemplateExerciseDTO]
}

extension TemplateDTO {
    /// Estimated completion time: default set work estimate plus configured rest targets.
    var targetCompletionTime: TimeInterval {
        let sets = exercises.flatMap(\.sets)
        let setWork = Double(sets.count) * 120
        let rest = sets.compactMap(\.restDuration).reduce(0, +)
        return setWork + rest
    }
}

struct TemplateExerciseDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let defaultLoggingType: SetLoggingType
    let order: Int
    let equipmentTypeOverride: EquipmentType?
    let sets: [TemplateSetDTO]

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        defaultLoggingType: SetLoggingType = .reps,
        order: Int,
        equipmentTypeOverride: EquipmentType? = nil,
        sets: [TemplateSetDTO]
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.defaultLoggingType = defaultLoggingType
        self.order = order
        self.equipmentTypeOverride = equipmentTypeOverride
        self.sets = sets
    }
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
    let templateName: String?
    let isFromArchivedTemplate: Bool
    let startedAt: Date
    let endedAt: Date?
    let status: SessionStatus
    let totalPauseDuration: TimeInterval
    let exercises: [SessionExerciseDTO]

    init(
        id: UUID,
        templateId: UUID?,
        templateName: String? = nil,
        isFromArchivedTemplate: Bool = false,
        startedAt: Date,
        endedAt: Date?,
        status: SessionStatus,
        totalPauseDuration: TimeInterval,
        exercises: [SessionExerciseDTO]
    ) {
        self.id = id
        self.templateId = templateId
        self.templateName = templateName
        self.isFromArchivedTemplate = isFromArchivedTemplate
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.totalPauseDuration = totalPauseDuration
        self.exercises = exercises
    }

    /// Template name for display — shows "Archived" for deleted templates, "Quick Start" for ad-hoc.
    var displayTemplateName: String {
        if isFromArchivedTemplate { return "Archived" }
        return templateName ?? "Quick Start"
    }
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
    let durationSeconds: TimeInterval?
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
        durationSeconds: TimeInterval? = nil,
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
        self.durationSeconds = durationSeconds
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
        self.durationSeconds = model.durationSeconds
        self.weight = model.weight
        self.setTimerStart = model.setTimerStart
        self.setTimerEnd = model.setTimerEnd
        self.restStart = model.restStart
        self.restEnd = model.restEnd
        self.noteLabel = model.noteLabel
        self.isUnrecorded = model.isUnrecorded
    }
}

extension SessionSetDTO {
    var restDuration: TimeInterval? {
        guard let restStart, let restEnd else { return nil }
        return max(0, restEnd.timeIntervalSince(restStart))
    }
}


extension SessionDTO {
    var actualDurationSeconds: TimeInterval {
        guard let endedAt else { return 0 }
        return max(0, endedAt.timeIntervalSince(startedAt) - totalPauseDuration)
    }
}

extension SessionSetDTO {
    var setDuration: TimeInterval? {
        guard let setTimerStart, let setTimerEnd else { return nil }
        return max(0, setTimerEnd.timeIntervalSince(setTimerStart))
    }

    var volumeKg: Double {
        Double(reps ?? 0) * (weight ?? 0)
    }
}
