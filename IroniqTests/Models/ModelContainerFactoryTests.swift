import XCTest
import SwiftData
@testable import Ironiq

final class ModelContainerFactoryTests: XCTestCase {
    func testPersistentContainerOpensWithProductionSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IroniqModelContainerFactoryTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let container = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        let context = ModelContext(container)
        let exercise = Exercise(
            name: "Schema Smoke Test",
            exerciseDescription: "Verifies the production persistent SwiftData store opens and writes.",
            equipmentType: .bodyweight,
            isSingleHand: false,
            muscleGroups: [.fullBody],
            iconName: "default",
            isCustom: true
        )

        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.map(\.name), ["Schema Smoke Test"])
    }

    func testInMemoryContainerOpensWithProductionSchema() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Template(name: "Schema Smoke Test"))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Template>())
        XCTAssertEqual(fetched.map(\.name), ["Schema Smoke Test"])
    }
}
