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
        Section("Sync") {
          HStack {
            Label(
              appState.syncStatusLabel,
              systemImage: appState.syncProvider == .apple ? "icloud.fill" : "externaldrive.fill"
            )
            .foregroundStyle(.white)
            Spacer()
            Image(
              systemName: appState.hasCompletedRequiredSync
                ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .foregroundStyle(
              appState.hasCompletedRequiredSync ? Color.ironiqGreen : Color.ironiqOrange)
          }

          if let account = appState.syncAccountLabel, !account.isEmpty {
            Text(account)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.55))
          }

          Button("Switch Sync Provider") {
            appState.showProviderSwitchWarning = true
          }
          .foregroundStyle(Color.ironiqOrange)
        }
        .listRowBackground(Color.ironiqSurface)

        Section("Preferences") {
          Picker("Units", selection: $state.unitSystem) {
            Text("Imperial (lbs)").tag(UnitSystem.imperial)
            Text("Metric (kg)").tag(UnitSystem.metric)
          }
          .foregroundStyle(.primary)
          .accessibilityIdentifier("unit_picker")

          Toggle("Dark Mode", isOn: $state.useDarkMode)
            .tint(Color.ironiqOrange)
            .accessibilityIdentifier("dark_mode_toggle")

          Stepper(
            "Rest reminder: \(state.restReminderSeconds)s",
            value: $state.restReminderSeconds,
            in: 30...300,
            step: 15
          )
          .foregroundStyle(.primary)
          .accessibilityIdentifier("rest_reminder_stepper")
        }
        .listRowBackground(Color.ironiqSurface)

        Section("Ironiq Pro") {
          if appState.isProUser {
            HStack {
              Label("Pro Active", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color.ironiqGreen)
              Spacer()
            }
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Ironiq Pro")
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
                .background(Color.ironiqOrange)
                .clipShape(Capsule())
                .accessibilityIdentifier("upgrade_pro_button")

                Button("Restore") {
                  Task { await storeKit.restorePurchases(appState: appState) }
                }
                .foregroundStyle(Color.ironiqOrange.opacity(0.8))
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
      .background(Color.ironiqDark)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)

      .alert("Switch sync provider?", isPresented: $state.showProviderSwitchWarning) {
        Button("Cancel", role: .cancel) {}
        Button("Switch", role: .destructive) {
          appState.clearSyncForProviderSwitch()
          appState.hasCompletedOnboarding = false
        }
      } message: {
        Text(
          "Your existing workouts and templates stay in the current drive. Earlier history will not appear after switching unless you switch back or migrate later."
        )
      }
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
