import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var exerciseDescription: String
    var equipmentType: String          // EquipmentType.rawValue — stored as String for SwiftData compatibility
    var isSingleHand: Bool
    var muscleGroupsRaw: String        // Comma-separated MuscleGroup.rawValue list
    var iconName: String
    var isCustom: Bool
    var isSeeded: Bool
    var defaultLoggingTypeRaw: String = SetLoggingType.reps.rawValue

    var equipmentTypeEnum: EquipmentType {
        get { EquipmentType(rawValue: equipmentType) ?? .other }
        set { equipmentType = newValue.rawValue }
    }

    var muscleGroups: [MuscleGroup] {
        get {
            muscleGroupsRaw
                .split(separator: ",")
                .compactMap { MuscleGroup(rawValue: String($0)) }
        }
        set {
            muscleGroupsRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }

    var defaultLoggingType: SetLoggingType {
        get { SetLoggingType(rawValue: defaultLoggingTypeRaw) ?? .reps }
        set { defaultLoggingTypeRaw = newValue.rawValue }
    }

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
        self.equipmentType = equipmentType.rawValue
        self.isSingleHand = isSingleHand
        self.muscleGroupsRaw = muscleGroups.map { $0.rawValue }.joined(separator: ",")
        self.iconName = iconName
        self.isCustom = isCustom
        self.isSeeded = isSeeded
        self.defaultLoggingTypeRaw = defaultLoggingType.rawValue
    }
}
