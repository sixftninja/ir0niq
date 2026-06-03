import SwiftUI

struct WatchStartConfirmView: View {
    @Environment(WatchSessionViewModel.self) private var vm
    let template: WatchTemplateInfo

    var body: some View {
        VStack(spacing: 12) {
            Text(template.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("\(template.exerciseCount) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Start Workout") {
                vm.sendStartTemplate(id: template.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "E8680A"))
            .font(.headline.weight(.bold))
        }
        .padding()
    }
}
