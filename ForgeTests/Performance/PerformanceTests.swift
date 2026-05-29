import XCTest
import SwiftData
@testable import Forge

/// Performance baselines for critical paths.
/// These tests alert us to regressions that slow down core operations.
final class PerformanceTests: XCTestCase {

    // MARK: - Session start time

    /// Session start should complete in well under 1 second even with SwiftData I/O.
    func testSessionStartTime() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let templateRepo = TemplateRepository(modelContainer: container)
        let sessionRepo = SessionRepository(modelContainer: container)

        // Create a small template
        let exerciseRepo = ExerciseRepository(modelContainer: container)
        let seedData = try SeedDataService.loadExercises(from: .main)
        _ = try await exerciseRepo.seedIfNeeded(exercises: seedData)
        let exercises = try await exerciseRepo.fetchAll()

        let templateId = try await templateRepo.insert(
            name: "Perf Test",
            exercises: [
                CreateTemplateExerciseInput(
                    exerciseId: exercises[0].id,
                    equipmentTypeOverride: nil,
                    sets: (0..<5).map { _ in CreateTemplateSetInput(targetReps: 5, restDuration: 90) }
                )
            ]
        )

        let engine = SessionEngine(templateRepository: templateRepo, sessionRepository: sessionRepo)

        let start = Date()
        try await engine.selectTemplate(templateId)
        _ = try await engine.startSession()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0,
            "Session start should be under 1 second, took \(String(format: "%.3f", elapsed))s")
    }

    /// Ad-hoc session start (no template) should be especially fast.
    func testAdHocSessionStartTime() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let engine = SessionEngine(
            templateRepository: TemplateRepository(modelContainer: container),
            sessionRepository: SessionRepository(modelContainer: container)
        )

        let start = Date()
        _ = try await engine.startAdHocSession()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 0.5,
            "Ad-hoc session start should be under 0.5s, took \(String(format: "%.3f", elapsed))s")
    }

    // MARK: - Template load time

    func testTemplateLoadWith50Templates() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let exerciseRepo = ExerciseRepository(modelContainer: container)
        let templateRepo = TemplateRepository(modelContainer: container)

        let seedData = try SeedDataService.loadExercises(from: .main)
        _ = try await exerciseRepo.seedIfNeeded(exercises: seedData)
        let exercises = try await exerciseRepo.fetchAll()

        // Insert 50 templates
        for i in 0..<50 {
            _ = try await templateRepo.insert(
                name: "Template \(i)",
                exercises: [
                    CreateTemplateExerciseInput(
                        exerciseId: exercises[i % exercises.count].id,
                        equipmentTypeOverride: nil,
                        sets: [CreateTemplateSetInput(targetReps: 8)]
                    )
                ]
            )
        }

        let start = Date()
        let templates = try await templateRepo.fetchAll()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(templates.count, 50)
        XCTAssertLessThan(elapsed, 1.0,
            "Loading 50 templates should be under 1s, took \(String(format: "%.3f", elapsed))s")
    }

    // MARK: - Exercise fetch time (seed data)

    func testExerciseFetchTime() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let exerciseRepo = ExerciseRepository(modelContainer: container)
        let seedData = try SeedDataService.loadExercises(from: .main)
        _ = try await exerciseRepo.seedIfNeeded(exercises: seedData)

        let start = Date()
        let exercises = try await exerciseRepo.fetchAll()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThanOrEqual(exercises.count, 80)
        XCTAssertLessThan(elapsed, 0.5,
            "Fetching 80+ exercises should be under 0.5s, took \(String(format: "%.3f", elapsed))s")
    }

    // MARK: - GZip compression time (session export)

    func testGZipCompressionTime() throws {
        // Simulate a realistic 5KB session JSON
        let largeJSON = String(repeating: "{\"set\":{\"reps\":5,\"weight\":100}}", count: 200).data(using: .utf8)!

        let start = Date()
        let compressed = try largeJSON.gzipped()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(compressed.isEmpty)
        XCTAssertLessThan(elapsed, 0.1,
            "Compressing 5KB should be under 0.1s, took \(String(format: "%.3f", elapsed))s")
    }

    // MARK: - Timer system performance

    func testTimerSystemSchedule100Timers() async throws {
        let timerSystem = TimerSystem()
        let start = Date()

        // Schedule 100 long-running timers (they won't fire in test duration)
        for i in 0..<100 {
            await timerSystem.schedule(.session(sessionId: UUID()), after: 3600) {}
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5,
            "Scheduling 100 timers should be under 0.5s, took \(String(format: "%.3f", elapsed))s")

        await timerSystem.cancelAll()
    }
}
