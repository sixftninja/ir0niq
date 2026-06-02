import XCTest
import SwiftData
@testable import Ironiq

// Tests for Phase 4: architecture cleanup.

@MainActor
final class Phase4Tests: XCTestCase {

    // MARK: - SwiftData versioned schema

    func testVersionedSchemaOpensContainer() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase4Schema_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        let container = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        let context = ModelContext(container)
        context.insert(Template(name: "VersionTest"))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Template>())
        XCTAssertEqual(fetched.map(\.name), ["VersionTest"])
    }

    func testInMemoryContainerUsesVersionedSchema() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        XCTAssertNotNil(container)
        let context = ModelContext(container)
        let exercise = Exercise(
            name: "Squat", exerciseDescription: "Test",
            equipmentType: .barbell, isSingleHand: false,
            muscleGroups: [.fullBody], iconName: "squat",
            isCustom: false, isSeeded: true
        )
        context.insert(exercise)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - Intent bridge

    func testIntentBridgeReturnsEngineAfterSet() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let engine = SessionEngine.make(modelContainer: container)
        SessionIntentBridge.shared.setEngine(engine)
        let retrieved = SessionIntentBridge.shared.engine()
        XCTAssertNotNil(retrieved)
    }

    func testSessionEngineCurrentAccessesBridge() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let engine = SessionEngine.make(modelContainer: container)
        SessionIntentBridge.shared.setEngine(engine)
        XCTAssertNotNil(SessionEngine.current)
    }

    // MARK: - Schema metadata

    func testIroniqSchemaV1ContainsAllModels() {
        let modelTypes = IroniqSchemaV1.models.map { ObjectIdentifier($0) }
        XCTAssertEqual(modelTypes.count, 8, "Expected 8 model types in V1 schema")
    }

    func testMigrationPlanHasOneSchema() {
        XCTAssertEqual(IroniqMigrationPlan.schemas.count, 1)
        XCTAssertEqual(IroniqMigrationPlan.stages.count, 0)
    }
}
