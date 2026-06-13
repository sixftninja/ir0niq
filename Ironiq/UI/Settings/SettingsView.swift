import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(AppState.self) private var appState
  @Environment(AppModel.self) private var appModel
  @Environment(SettingsViewModel.self) private var vm
  @Environment(HistoryViewModel.self) private var historyVM
  @State private var isRestoring = false
  @State private var exportItem: CSVExportItem?

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
            syncHealthIndicator
          }

          if let account = appState.syncAccountLabel, !account.isEmpty {
            Text(account)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.55))
          }

          Text(appState.syncHealthLabel)
            .font(.caption)
            .foregroundStyle(appState.syncHealthIsOK ? Color.ironiqGreen : Color.ironiqOrange)
            .accessibilityIdentifier("sync_health_label")

          if !PendingExportQueue.shared.isEmpty {
            Text("\(PendingExportQueue.shared.allItems().count) item(s) waiting to sync")
              .font(.caption)
              .foregroundStyle(Color.ironiqOrange)
          }

          Button("Switch Login") {
            appState.showProviderSwitchWarning = true
          }
          .foregroundStyle(Color.ironiqOrange)

          Button {
            isRestoring = true
            Task {
              await appModel.performStartupSync()
              isRestoring = false
            }
          } label: {
            if isRestoring {
              HStack(spacing: 8) {
                ProgressView().tint(Color.ironiqOrange)
                Text("Restoring…")
              }
            } else {
              Text("Restore from Cloud")
            }
          }
          .foregroundStyle(Color.ironiqOrange)
          .disabled(isRestoring || !appState.hasCompletedRequiredSync)
          .accessibilityIdentifier("restore_from_cloud_button")
        }
        .listRowBackground(Color.ironiqSurface)

        Section("Preferences") {
          Picker("Units", selection: $state.unitSystem) {
            Text("Imperial (lbs)").tag(UnitSystem.imperial)
            Text("Metric (kg)").tag(UnitSystem.metric)
          }
          .foregroundStyle(.primary)
          .accessibilityIdentifier("unit_picker")

          Stepper(
            "Log reminder: \(state.restReminderSeconds)s",
            value: $state.restReminderSeconds,
            in: 30...300,
            step: 15
          )
          .foregroundStyle(.primary)
          .accessibilityIdentifier("logging_reminder_stepper")

          Stepper(
            "Sessions per week: \(state.sessionsPerWeekTarget)",
            value: $state.sessionsPerWeekTarget,
            in: 1...14,
            step: 1
          )
          .foregroundStyle(.primary)
          .accessibilityIdentifier("sessions_per_week_stepper")
        }
        .listRowBackground(Color.ironiqSurface)

        Section("Data") {
          Button {
            exportItem = CSVExportItem(csv: buildCSV())
          } label: {
            Label("Export History", systemImage: "square.and.arrow.up")
              .foregroundStyle(historyVM.sessions.isEmpty ? Color.white.opacity(0.35) : Color.ironiqOrange)
          }
          .disabled(historyVM.sessions.isEmpty)
          .accessibilityIdentifier("export_history_button")
        }
        .listRowBackground(Color.ironiqSurface)

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
      .sheet(item: $exportItem) { item in
        ShareSheet(activityItems: [item.fileURL])
      }
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
    }
  }

  @ViewBuilder
  private var syncHealthIndicator: some View {
    switch appState.syncHealth {
    case .healthy:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Color.ironiqGreen)
    case .failing:
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(Color.ironiqOrange)
    case .unknown:
      Image(systemName: "clock.fill")
        .foregroundStyle(.white.opacity(0.4))
    }
  }

  private func buildCSV() -> String {
    var lines = ["date,template_name,exercise_name,set_number,reps,weight_kg,set_duration_seconds,rest_duration_seconds,session_status"]
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    for session in historyVM.sessions {
      let templateName = session.displayTemplateName
      let dateStr = df.string(from: session.startedAt)
      let status = session.status.rawValue
      for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
        for set in exercise.sets.sorted(by: { $0.order < $1.order }) {
          guard set.status == .logged else { continue }
          let reps = set.reps.map(String.init) ?? ""
          let weight = set.weight.map { String(format: "%.2f", $0) } ?? ""
          let setDur = set.setDuration.map { String(format: "%.0f", $0) } ?? ""
          let restDur = set.restDuration.map { String(format: "%.0f", $0) } ?? ""
          lines.append("\(dateStr),\(templateName),\(exercise.exerciseName),\(set.order + 1),\(reps),\(weight),\(setDur),\(restDur),\(status)")
        }
      }
    }
    return lines.joined(separator: "\n")
  }
}

// MARK: - CSV export helpers

struct CSVExportItem: Identifiable {
  let id = UUID()
  let csv: String
  var fileURL: URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ironiq_history_\(id.uuidString.prefix(8)).csv")
    try? csv.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let activityItems: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }
  func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
  SettingsView()
    .environment(AppState())
    .environment(SettingsViewModel())
    .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: AppState()))
}
