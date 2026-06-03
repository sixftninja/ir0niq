import SwiftUI

struct WatchTemplateListView: View {
    @Environment(WatchSessionViewModel.self) private var vm

    var body: some View {
        NavigationStack {
            if vm.templates.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "iphone")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Open Ironiq\non iPhone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.templates, id: \.id) { template in
                    NavigationLink {
                        WatchStartConfirmView(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(template.exerciseCount) exercises")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Workouts")
            }
        }
    }
}
