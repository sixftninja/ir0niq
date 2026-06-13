import Foundation
import SwiftData

@Model
final class Template {
    var id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.exercises = []
    }
}

@Model
final class TemplateExercise {
    var id: UUID
    var template: Template?
    var exercise: Exercise?
    var order: Int
    var equipmentTypeOverride: String?   // EquipmentType.rawValue, nil means use exercise default
    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.templateExercise)
    var sets: [TemplateSet]

    var equipmentTypeOverrideEnum: EquipmentType? {
        get {
            guard let raw = equipmentTypeOverride else { return nil }
            return EquipmentType(rawValue: raw)
        }
        set { equipmentTypeOverride = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        order: Int,
        equipmentTypeOverride: EquipmentType? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.order = order
        self.equipmentTypeOverride = equipmentTypeOverride?.rawValue
        self.sets = []
    }
}

@Model
final class TemplateSet {
    var id: UUID
    var templateExercise: TemplateExercise?
    var order: Int
    var targetReps: Int?
    var targetWeight: Double?
    var targetDuration: TimeInterval?
    var restDuration: TimeInterval?
    var noteLabel: String?

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
}
