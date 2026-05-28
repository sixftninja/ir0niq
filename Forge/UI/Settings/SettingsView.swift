import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var vm

    var body: some View {
        NavigationStack {
            @Bindable var state = appState
            List {
                Section("Preferences") {
                    Picker("Units", selection: $state.unitSystem) {
                        Text("Imperial (lbs)").tag(UnitSystem.imperial)
                        Text("Metric (kg)").tag(UnitSystem.metric)
                    }
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("unit_picker")
                }
                .listRowBackground(Color(white: 0.1))

                Section("Forge Pro") {
                    if appState.isProUser {
                        HStack {
                            Label("Pro Active", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.forgeGreen)
                            Spacer()
                        }
                    } else {
                        Button("Upgrade to Forge Pro") {
                            // StoreKit purchase — Phase 5
                            appState.isProUser = true
                        }
                        .foregroundStyle(Color.forgeOrange)
                        .accessibilityIdentifier("upgrade_pro_button")
                    }
                }
                .listRowBackground(Color(white: 0.1))

                Section("About") {
                    HStack {
                        Text("Version")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(vm.appVersion)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .listRowBackground(Color(white: 0.1))

                Section {
                    Button("Reset Onboarding") {
                        vm.resetOnboarding(appState: appState)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityIdentifier("reset_onboarding_button")
                }
                .listRowBackground(Color(white: 0.1))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.forgeDark)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(SettingsViewModel())
}
