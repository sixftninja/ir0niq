import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var vm
    @Environment(StoreKitService.self) private var storeKit
    @State private var showPurchaseError = false
    @State private var purchaseErrorMessage = ""

    var body: some View {
        NavigationStack {
            @Bindable var state = appState
            List {
                Section("Preferences") {
                    Picker("Units", selection: $state.unitSystem) {
                        Text("Imperial (lbs)").tag(UnitSystem.imperial)
                        Text("Metric (kg)").tag(UnitSystem.metric)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("unit_picker")

                    Toggle("Dark Mode", isOn: $state.useDarkMode)
                        .tint(Color.forgeOrange)
                        .accessibilityIdentifier("dark_mode_toggle")
                }
                .listRowBackground(Color.forgeSurface)

                Section("Forge Pro") {
                    if appState.isProUser {
                        HStack {
                            Label("Pro Active", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.forgeGreen)
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Forge Pro")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Unlimited templates · Full history · Analytics · Export")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))

                            HStack(spacing: 12) {
                                Button(storeKit.isPurchasing ? "Purchasing…" : "Upgrade") {
                                    Task {
                                        do {
                                            _ = try await storeKit.purchase(appState: appState)
                                        } catch {
                                            purchaseErrorMessage = error.localizedDescription
                                            showPurchaseError = true
                                        }
                                    }
                                }
                                .disabled(storeKit.isPurchasing)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.forgeOrange)
                                .clipShape(Capsule())
                                .accessibilityIdentifier("upgrade_pro_button")

                                Button("Restore") {
                                    Task { await storeKit.restorePurchases(appState: appState) }
                                }
                                .foregroundStyle(Color.forgeOrange.opacity(0.8))
                                .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
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
            
            .alert("Purchase Failed", isPresented: $showPurchaseError) {
                Button("OK") {}
            } message: {
                Text(purchaseErrorMessage)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(SettingsViewModel())
        .environment(StoreKitService.shared)
}
