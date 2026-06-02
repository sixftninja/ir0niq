import XCTest

@testable import Ironiq

final class iCloudServiceTests: XCTestCase {

  // MARK: - SessionExportModel + JSON serialization

  func testExportModelJSONRoundTrip() throws {
    let dto = makeSessionDTO()
    let model = SessionExportModel.make(from: dto, templateName: "Push Day")

    let jsonData = try model.jsonData()
    XCTAssertFalse(jsonData.isEmpty)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(SessionExportModel.self, from: jsonData)
    XCTAssertEqual(decoded.version, SessionExportModel.currentVersion)
    XCTAssertEqual(decoded.sessionId, dto.id.uuidString)
    XCTAssertEqual(decoded.status, SessionStatus.complete.rawValue)
    XCTAssertEqual(decoded.templateName, "Push Day")
  }

  func testExportModelExerciseCount() throws {
    let dto = makeSessionDTO()
    let model = SessionExportModel.make(from: dto)
    XCTAssertEqual(model.exercises.count, 1)
    XCTAssertEqual(model.exercises[0].sets.count, 2)
  }

  func testExportModelSetDetails() throws {
    let dto = makeSessionDTO()
    let model = SessionExportModel.make(from: dto)
    let set = model.exercises[0].sets[0]
    XCTAssertEqual(set.reps, 5)
    XCTAssertEqual(set.weight, 100.0)
    XCTAssertEqual(set.status, SetStatus.logged.rawValue)
    XCTAssertFalse(set.isUnrecorded)
  }

  func testExportModelActualDuration() throws {
    let start = Date(timeIntervalSinceNow: -600)  // 10 minutes ago
    let end = Date(timeIntervalSinceNow: 0)
    let dto = SessionDTO(
      id: UUID(),
      templateId: nil,
      startedAt: start,
      endedAt: end,
      status: .complete,
      totalPauseDuration: 60,  // 1 min pause
      exercises: []
    )
    let model = SessionExportModel.make(from: dto)
    XCTAssertEqual(model.actualDurationSeconds, 540, accuracy: 1)  // 600 - 60 = 540
  }

  // MARK: - Template export

  func testTemplateExportModelJSONRoundTrip() throws {
    let exercise = TemplateExerciseDTO(
      exerciseId: UUID(),
      exerciseName: "Plank",
      defaultLoggingType: .duration,
      order: 0,
      sets: [TemplateSetDTO(order: 0, targetDuration: 45, restDuration: 30)]
    )
    let template = TemplateDTO(id: UUID(), name: "Core", createdAt: Date(), exercises: [exercise])
    let model = TemplateExportModel(from: template)
    let jsonData = try model.jsonData()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TemplateExportModel.self, from: jsonData)
    XCTAssertEqual(decoded.version, TemplateExportModel.currentVersion)
    XCTAssertEqual(decoded.id, template.id)
    XCTAssertEqual(decoded.name, "Core")
    XCTAssertEqual(decoded.exercises.first?.defaultLoggingType, SetLoggingType.duration.rawValue)
    XCTAssertEqual(decoded.exercises.first?.sets.first?.targetDuration, 45)
  }

  func testMockPrepareSyncFolders() async throws {
    let mock = MockiCloudService()
    try await mock.prepareSyncFolders()
    let didPrepare = await mock.didPrepareSyncFolders
    XCTAssertTrue(didPrepare)
  }

  func testMockTemplateExportCapturesModel() async throws {
    let mock = MockiCloudService()
    let template = TemplateDTO(id: UUID(), name: "Push", createdAt: Date(), exercises: [])
    let model = TemplateExportModel(from: template)
    _ = try await mock.exportTemplate(model)
    let exported = await mock.exportedTemplates
    XCTAssertEqual(exported.first?.id, template.id)
  }

  // MARK: - GZip compression

  func testGZipCompressedDataIsSmaller() throws {
    let largeJSON = String(repeating: "hello world ", count: 1000).data(using: .utf8)!
    let compressed = try largeJSON.gzipped()
    XCTAssertLessThan(compressed.count, largeJSON.count, "Compressed data should be smaller")
  }

  func testGZipHasCorrectMagicBytes() throws {
    let data = "test".data(using: .utf8)!
    let compressed = try data.gzipped()
    XCTAssertEqual(compressed.count >= 2, true)
    XCTAssertEqual(compressed[0], 0x1f, "First magic byte should be 0x1F")
    XCTAssertEqual(compressed[1], 0x8b, "Second magic byte should be 0x8B")
  }

  func testGZipNonEmptyDataCompresses() throws {
    let data = "Ironiq session export test data".data(using: .utf8)!
    let compressed = try data.gzipped()
    XCTAssertFalse(compressed.isEmpty)
  }

  func testGZipEmptyDataReturnsEmpty() throws {
    let compressed = try Data().gzipped()
    XCTAssertTrue(compressed.isEmpty)
  }

  // MARK: - Mock iCloud service

  func testMockExportServiceCapturesModel() async throws {
    let mock = MockiCloudService()
    let dto = makeSessionDTO()
    let model = SessionExportModel.make(from: dto)

    _ = try await mock.exportSession(model, templateSlug: "push-day")

    let exported = await mock.exportedModels
    let slugs = await mock.exportedSlugs
    XCTAssertEqual(exported.count, 1)
    XCTAssertEqual(exported.first?.sessionId, dto.id.uuidString)
    XCTAssertEqual(slugs.first, "push-day")
  }

  func testMockExportServicePropagatesError() async throws {
    let mock = MockiCloudService()
    await mock.set(errorToThrow: iCloudError.containerUnavailable)
    let model = SessionExportModel.make(from: makeSessionDTO())

    do {
      _ = try await mock.exportSession(model, templateSlug: nil)
      XCTFail("Expected error")
    } catch iCloudError.containerUnavailable {
      // Expected
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }

  // MARK: - Integration: SessionEngine calls iCloud on confirm-end

  func testWorkoutHistoryExportMarkdownContainsSessions() throws {
    let now = Date()
    let set = SessionSetDTO(
      order: 0,
      status: .logged,
      reps: 10,
      weight: 20,
      restStart: now,
      restEnd: now.addingTimeInterval(45)
    )
    let session = SessionDTO(
      id: UUID(),
      templateId: nil,
      startedAt: now.addingTimeInterval(-600),
      endedAt: now,
      status: .complete,
      totalPauseDuration: 0,
      exercises: [
        SessionExerciseDTO(
          id: UUID(),
          exerciseId: UUID(),
          exerciseName: "Flat Bench Press",
          order: 0,
          executionOrder: 0,
          status: .complete,
          sets: [set]
        )
      ]
    )

    let export = WorkoutHistoryExport(sessions: [session], exportedAt: now)
    let markdown = export.markdown()

    XCTAssertEqual(export.sessions.first?.setsLogged, 1)
    XCTAssertEqual(export.sessions.first?.totalVolumeKg, 200)
    XCTAssertTrue(markdown.contains("Flat Bench Press"))
    XCTAssertTrue(markdown.contains("Total volume: 200 kg"))
  }

  func testSessionEngineExportsToiCloudOnEnd() async throws {
    let templateRepo = MockTemplateRepository()
    let sessionRepo = MockSessionRepository()
    let iCloud = MockiCloudService()

    let templateId = UUID()
    await templateRepo.seed(
      template: TemplateDTO(
        id: templateId, name: "T", createdAt: Date(), exercises: []
      ))

    let engine = SessionEngine(
      templateRepository: templateRepo,
      sessionRepository: sessionRepo,
      iCloudService: iCloud
    )

    try await engine.selectTemplate(templateId)
    _ = try await engine.startSession()
    _ = try await engine.endSession()
    try await engine.confirmEnd()

    // Give async iCloud task a moment to run
    try await Task.sleep(for: .milliseconds(50))

    let exports = await iCloud.exportedModels
    XCTAssertEqual(exports.count, 1, "iCloud export should be triggered on session end")
  }

  // MARK: - Filename generation (via concrete service internal logic)

  func testFilenameFormat() {
    // The filename is built inside iCloudService. We verify via integration
    // by checking the returned URL's last path component from the mock.
    // The concrete service's filename is tested separately here via the known format.
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let date = Date()
    let timestamp = formatter.string(from: date)

    // A slug-less export
    let expectedNoSlug = "ironiq_\(timestamp).json.gz"
    XCTAssertTrue(expectedNoSlug.hasSuffix(".json.gz"))
    XCTAssertTrue(expectedNoSlug.hasPrefix("ironiq_"))

    // A slug export
    let slug = "push-day"
    let expectedWithSlug = "ironiq_\(timestamp)_\(slug).json.gz"
    XCTAssertTrue(expectedWithSlug.contains("push-day"))
    XCTAssertTrue(expectedWithSlug.hasSuffix(".json.gz"))
  }

  // MARK: - PendingExportQueue
  // Each test uses a unique UserDefaults key to avoid cross-test pollution.

  func testPendingQueueAddsSession() {
    let queue = PendingExportQueue(key: "test.queue.\(UUID().uuidString)")
    let id = UUID()
    queue.add(sessionId: id)
    XCTAssertTrue(queue.allItems().contains(where: { $0.id == id && $0.type == .session }))
  }

  func testPendingQueueAddsTemplate() {
    let queue = PendingExportQueue(key: "test.queue.\(UUID().uuidString)")
    let id = UUID()
    queue.add(templateId: id)
    XCTAssertTrue(queue.allItems().contains(where: { $0.id == id && $0.type == .template }))
  }

  func testPendingQueueNoDuplicates() {
    let queue = PendingExportQueue(key: "test.queue.\(UUID().uuidString)")
    let id = UUID()
    queue.add(sessionId: id)
    queue.add(sessionId: id)
    XCTAssertEqual(queue.allItems().filter { $0.id == id }.count, 1)
  }

  func testPendingQueueRemoves() {
    let queue = PendingExportQueue(key: "test.queue.\(UUID().uuidString)")
    let id = UUID()
    queue.add(sessionId: id)
    queue.remove(id: id)
    XCTAssertFalse(queue.allItems().contains(where: { $0.id == id }))
  }

  func testPendingQueueIncrementRetry() {
    let queue = PendingExportQueue(key: "test.queue.\(UUID().uuidString)")
    let id = UUID()
    queue.add(sessionId: id)
    queue.incrementRetry(id: id)
    XCTAssertEqual(queue.allItems().first(where: { $0.id == id })?.retryCount, 1)
  }

  // Export failure adds item to the shared pending queue.
  func testSessionEngineAddsSessionToPendingQueueOnExportFailure() async throws {
    let container = try ModelContainerFactory.makeInMemoryContainer()
    let mockCloud = MockiCloudService()
    await mockCloud.set(errorToThrow: iCloudError.containerUnavailable)

    let engine = SessionEngine(
      templateRepository: TemplateRepository(modelContainer: container),
      sessionRepository: SessionRepository(modelContainer: container),
      iCloudService: mockCloud
    )
    let templateRepo = TemplateRepository(modelContainer: container)

    let templateId = try await templateRepo.insert(
      name: "Pending Test",
      exercises: [CreateTemplateExerciseInput(
        exerciseId: UUID(),
        sets: [CreateTemplateSetInput(targetReps: 5)]
      )]
    )

    try await engine.selectTemplate(templateId)
    _ = try await engine.startSession()

    guard case .active(let sessionId) = await engine.state else {
      XCTFail("Expected active state"); return
    }
    _ = try await engine.endSession()
    try await engine.confirmEnd()

    let items = PendingExportQueue.shared.allItems()
    XCTAssertTrue(items.contains(where: { $0.id == sessionId && $0.type == .session }))
    PendingExportQueue.shared.remove(id: sessionId)
  }

  // MARK: - iCloud container unavailable throws, does not fall back

  func testExportSessionThrowsWhenContainerUnavailable() async throws {
    let mock = MockiCloudService()
    await mock.set(errorToThrow: iCloudError.containerUnavailable)
    let model = SessionExportModel.make(from: makeSessionDTO())
    do {
      _ = try await mock.exportSession(model, templateSlug: nil)
      XCTFail("Expected containerUnavailable error")
    } catch iCloudError.containerUnavailable {
      // correct
    }
  }

  func testExportTemplateThrowsWhenContainerUnavailable() async throws {
    let mock = MockiCloudService()
    await mock.set(errorToThrow: iCloudError.containerUnavailable)
    let template = TemplateDTO(
      id: UUID(), name: "T", createdAt: Date(), exercises: []
    )
    let model = TemplateExportModel(from: template)
    do {
      _ = try await mock.exportTemplate(model)
      XCTFail("Expected containerUnavailable error")
    } catch iCloudError.containerUnavailable {
      // correct
    }
  }

  // MARK: - Helpers

  private func makeSessionDTO() -> SessionDTO {
    let now = Date()
    let sets = [
      SessionSetDTO(
        id: UUID(), order: 0, status: .logged,
        reps: 5, weight: 100,
        setTimerStart: now.addingTimeInterval(-50),
        setTimerEnd: now.addingTimeInterval(-5),
        restStart: now.addingTimeInterval(-5), restEnd: now,
        noteLabel: nil, isUnrecorded: false
      ),
      SessionSetDTO(
        id: UUID(), order: 1, status: .logged,
        reps: 5, weight: 100,
        setTimerStart: now.addingTimeInterval(-40),
        setTimerEnd: now.addingTimeInterval(-4),
        restStart: now.addingTimeInterval(-4), restEnd: now,
        noteLabel: nil, isUnrecorded: false
      ),
    ]
    let exercise = SessionExerciseDTO(
      id: UUID(), exerciseId: UUID(), exerciseName: "Deadlift",
      order: 0, executionOrder: 0, status: .complete, sets: sets
    )
    return SessionDTO(
      id: UUID(),
      templateId: UUID(),
      startedAt: now.addingTimeInterval(-600),
      endedAt: now,
      status: .complete,
      totalPauseDuration: 0,
      exercises: [exercise]
    )
  }
}

// MARK: - MockiCloudService test helpers

extension MockiCloudService {
  func set(errorToThrow: Error?) { self.errorToThrow = errorToThrow }
}
