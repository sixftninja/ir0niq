import SwiftUI

struct ExerciseRowView: View {
    let exercise: ExerciseDTO

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconSystemName(exercise.equipmentType))
                .font(.system(size: 20))
                .foregroundStyle(Color.ironiqOrange)
                .frame(width: 36, height: 36)
                .background(Color.ironiqOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body).bold()
                    .foregroundStyle(.white)
                Text(exercise.muscleGroups.prefix(2).map(\.displayName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if exercise.isSingleHand {
                Text("Single")
                    .font(.caption2).bold()
                    .foregroundStyle(Color.ironiqOrange)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.ironiqOrange.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.equipmentType.displayName)")
    }

    private func iconSystemName(_ equipment: EquipmentType) -> String {
        switch equipment {
        case .barbell, .dumbbell: return "dumbbell"
        case .cable, .machine: return "wrench.and.screwdriver"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .kettlebell: return "circle.hexagongrid"
        case .resistanceBand: return "link"
        case .other: return "square.grid.2x2"
        }
    }
}

#Preview {
    List {
        ExerciseRowView(exercise: ExerciseDTO(
            id: UUID(), name: "Deadlift", exerciseDescription: "Hip hinge",
            equipmentType: .barbell, isSingleHand: false,
            muscleGroups: [.back, .glutes, .hamstrings],
            iconName: "deadlift", isCustom: false, isSeeded: true
        ))
        ExerciseRowView(exercise: ExerciseDTO(
            id: UUID(), name: "Lateral Raise", exerciseDescription: "Shoulder raise",
            equipmentType: .dumbbell, isSingleHand: false,
            muscleGroups: [.shoulders],
            iconName: "lateral-raise", isCustom: false, isSeeded: true
        ))
    }
    .listStyle(.plain)
    .background(Color.ironiqDark)
}
