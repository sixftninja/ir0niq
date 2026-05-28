import SwiftUI

/// Shows in-progress sets before confirming session end. (Edge case 3)
struct ReviewBeforeSavingView: View {
    @Environment(SessionViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    let unloggedSets: [UnloggedSetInfo]
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if unloggedSets.isEmpty {
                    ContentUnavailableView(
                        "All Sets Logged",
                        systemImage: "checkmark.circle.fill",
                        description: Text("Your session is ready to save.")
                    )
                    .background(Color.forgeDark)
                } else {
                    List {
                        Section {
                            Text("The following sets were started but not logged. They will be marked as Not Performed.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.clear)

                        Section("Unlogged Sets") {
                            ForEach(unloggedSets, id: \.setId) { info in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.forgeRed)
                                    Text("Set \(info.setOrder + 1)")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("Not Performed")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.forgeDark)
                }

                ForgeButton("Save Session") {
                    onConfirm()
                    dismiss()
                }
                .accessibilityIdentifier("confirm_save_button")
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                Button("Go Back") {
                    vm.cancelEnd()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 16)
                .accessibilityIdentifier("cancel_end_button")
            }
            .background(Color.forgeDark)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
