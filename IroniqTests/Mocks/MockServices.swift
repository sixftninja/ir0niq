import Foundation

@testable import Ironiq

// MARK: - MockHealthKitService
// final class (not actor) because isAvailable() is synchronous in the protocol.
// @unchecked Sendable is safe — tests are single-threaded.

final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
  var availableResult = true
  var authorizationError: Error? = nil
  var startWorkoutError: Error? = nil
  var endWorkoutError: Error? = nil
  var workoutIdToReturn: UUID? = UUID()

  private(set) var startedWorkouts: [(sessionId: UUID, startDate: Date)] = []
  private(set) var endedWorkouts: [(sessionId: UUID, endDate: Date)] = []
  private(set) var energySamples: [(kcal: Double, date: Date)] = []

  func isAvailable() -> Bool { availableResult }

  func requestAuthorization() async throws {
    if let error = authorizationError { throw error }
  }

  func startWorkout(sessionId: UUID, startDate: Date) async throws {
    if let error = startWorkoutError { throw error }
    startedWorkouts.append((sessionId, startDate))
  }

  func endWorkout(sessionId: UUID, endDate: Date) async throws -> UUID? {
    if let error = endWorkoutError { throw error }
    endedWorkouts.append((sessionId, endDate))
    return workoutIdToReturn
  }

  func addActiveEnergyBurned(_ kcal: Double, at date: Date) async throws {
    energySamples.append((kcal, date))
  }

  // Test helpers
  func set(availableResult: Bool) { self.availableResult = availableResult }
  func set(authorizationError: Error?) { self.authorizationError = authorizationError }
  func set(startWorkoutError: Error?) { self.startWorkoutError = startWorkoutError }
  func set(endWorkoutError: Error?) { self.endWorkoutError = endWorkoutError }
  func set(workoutIdToReturn: UUID?) { self.workoutIdToReturn = workoutIdToReturn }
}

// MARK: - MockWatchSyncService

actor MockWatchSyncService: WatchSyncServiceProtocol {
  private(set) var activated = false
  private(set) var sentStates: [WatchSessionStateMessage] = []
  private(set) var completionHandler: WatchMessageHandler?
  var reachableResult = true

  var isReachable: Bool { reachableResult }

  func activate() async { activated = true }

  func sendSessionState(_ message: WatchSessionStateMessage) async {
    sentStates.append(message)
  }

  func onSetCompletion(_ handler: @escaping WatchMessageHandler) async {
    completionHandler = handler
  }

  func onWatchAction(_ handler: @escaping WatchActionHandler) async {}

  func simulateSetCompletion(_ message: WatchSetCompletionMessage) async {
    completionHandler?(message)
  }
}

// MARK: - MockiCloudService (actor — all methods are async, no sync requirements)

actor MockiCloudService: iCloudServiceProtocol {
  private(set) var exportedModels: [SessionExportModel] = []
  private(set) var exportedSlugs: [String?] = []
  private(set) var exportedTemplates: [TemplateExportModel] = []
  private(set) var didPrepareSyncFolders = false
  var errorToThrow: Error? = nil
  var urlToReturn: URL = URL(fileURLWithPath: "/tmp/ironiq_test.json.gz")

  func prepareSyncFolders() async throws {
    if let error = errorToThrow { throw error }
    didPrepareSyncFolders = true
  }

  func exportSession(_ model: SessionExportModel, templateSlug: String?) async throws -> URL {
    if let error = errorToThrow { throw error }
    exportedModels.append(model)
    exportedSlugs.append(templateSlug)
    return urlToReturn
  }

  func exportTemplate(_ model: TemplateExportModel) async throws -> URL {
    if let error = errorToThrow { throw error }
    exportedTemplates.append(model)
    return urlToReturn
  }
}
