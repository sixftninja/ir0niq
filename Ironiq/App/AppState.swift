import Foundation
import Observation
import SwiftUI

enum SyncProvider: String, CaseIterable, Codable {
  case apple
  case google

  var displayName: String {
    switch self {
    case .apple: return "Apple"
    case .google: return "Google"
    }
  }
}

enum SyncHealthState: Equatable {
  case healthy
  case failing(String)
  case unknown
}

@MainActor
@Observable
final class AppState {
  private enum Keys {
    static let syncProvider = "syncProvider"
    static let syncAccountId = "syncAccountId"
    static let syncAccountLabel = "syncAccountLabel"
    static let syncEnabled = "syncEnabled"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
  }

  // iCloud KV store — persists across reinstalls on the same iCloud account.
  private static let kv = NSUbiquitousKeyValueStore.default

  var unitSystem: UnitSystem = .imperial
  var isProUser: Bool = false

  // Read from UserDefaults OR iCloud KV — whichever is true survives reinstalls.
  var hasCompletedOnboarding: Bool =
    UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    || AppState.kv.bool(forKey: Keys.hasCompletedOnboarding)
    || CommandLine.arguments.contains("--skip-onboarding")
  {
    didSet {
      UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
      AppState.kv.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
    }
  }

  var useDarkMode: Bool = true
  var restReminderSeconds: Int = 120

  var syncProvider: SyncProvider? = (
    UserDefaults.standard.string(forKey: Keys.syncProvider)
    ?? AppState.kv.string(forKey: Keys.syncProvider)
  ).flatMap(SyncProvider.init(rawValue:))

  var syncAccountId: String? =
    UserDefaults.standard.string(forKey: Keys.syncAccountId)
    ?? AppState.kv.string(forKey: Keys.syncAccountId)

  var syncAccountLabel: String? =
    UserDefaults.standard.string(forKey: Keys.syncAccountLabel)
    ?? AppState.kv.string(forKey: Keys.syncAccountLabel)

  var syncStatusMessage: String? = nil

  var syncEnabled: Bool =
    UserDefaults.standard.bool(forKey: Keys.syncEnabled)
    || AppState.kv.bool(forKey: Keys.syncEnabled)

  var syncHealth: SyncHealthState = .unknown
  var isPreparingSync = false
  var showProviderSwitchWarning = false

  var hasCompletedRequiredSync: Bool {
    syncEnabled
      || CommandLine.arguments.contains("--skip-onboarding")
      || CommandLine.arguments.contains("--start-adhoc-session")
  }

  var syncStatusLabel: String {
    guard let syncProvider else { return "Not connected" }
    return "\(syncProvider.displayName) Drive connected"
  }

  var syncHealthLabel: String {
    switch syncHealth {
    case .healthy: return "Sync up to date"
    case .failing(let msg): return "Sync issue: \(msg)"
    case .unknown: return "Checking sync…"
    }
  }

  var syncHealthIsOK: Bool {
    if case .healthy = syncHealth { return true }
    return false
  }

  func markSyncHealthy() {
    syncHealth = .healthy
  }

  func markSyncFailing(_ reason: String) {
    syncHealth = .failing(reason)
  }

  func completeSync(provider: SyncProvider, accountId: String, accountLabel: String?) {
    syncProvider = provider
    syncAccountId = accountId
    syncAccountLabel = accountLabel

    UserDefaults.standard.set(provider.rawValue, forKey: Keys.syncProvider)
    UserDefaults.standard.set(accountId, forKey: Keys.syncAccountId)
    UserDefaults.standard.set(accountLabel, forKey: Keys.syncAccountLabel)
    syncEnabled = true
    UserDefaults.standard.set(true, forKey: Keys.syncEnabled)

    // Mirror to iCloud KV so reinstalls on the same account skip onboarding.
    AppState.kv.set(provider.rawValue, forKey: Keys.syncProvider)
    AppState.kv.set(accountId, forKey: Keys.syncAccountId)
    AppState.kv.set(accountLabel as Any, forKey: Keys.syncAccountLabel)
    AppState.kv.set(true, forKey: Keys.syncEnabled)
    AppState.kv.synchronize()

    syncStatusMessage = "\(provider.displayName) sync is ready."
    syncHealth = .healthy
  }

  func clearSyncForProviderSwitch() {
    syncProvider = nil
    syncAccountId = nil
    syncAccountLabel = nil

    UserDefaults.standard.removeObject(forKey: Keys.syncProvider)
    UserDefaults.standard.removeObject(forKey: Keys.syncAccountId)
    UserDefaults.standard.removeObject(forKey: Keys.syncAccountLabel)
    syncEnabled = false
    UserDefaults.standard.set(false, forKey: Keys.syncEnabled)

    AppState.kv.removeObject(forKey: Keys.syncProvider)
    AppState.kv.removeObject(forKey: Keys.syncAccountId)
    AppState.kv.removeObject(forKey: Keys.syncAccountLabel)
    AppState.kv.set(false, forKey: Keys.syncEnabled)
    AppState.kv.synchronize()

    syncStatusMessage = nil
    syncHealth = .unknown
  }

  // MARK: - Pro feature limits (nonisolated so they can be read from any context)
  nonisolated static let freeTemplateLimit = 7
  nonisolated static let freeHistoryDays = 90
}
