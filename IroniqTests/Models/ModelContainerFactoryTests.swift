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

    // Backup is created before any store files are deleted.
    func testBackupCreatedBeforeWipe() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IroniqBackupTest_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create a real store with data.
        let container = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        let context = ModelContext(container)
        context.insert(Template(name: "BackupTest"))
        try context.save()

        // Back up using the factory method.
        let backupDir = try ModelContainerFactory.backupPersistentStore(storeURL: storeURL)

        // The backup directory must exist and contain at least the main sqlite file.
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path), "Backup directory missing")
        let backupContents = try FileManager.default.contentsOfDirectory(atPath: backupDir.path)
        XCTAssertTrue(backupContents.contains("Ironiq.sqlite"), "Backup must include the sqlite file")
    }

    // After a backup, the original store files are still in place (backup does not delete them).
    func testBackupDoesNotDeleteOriginalStore() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IroniqBackupNoDelete_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        try ModelContainerFactory.backupPersistentStore(storeURL: storeURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "Original store should still exist after backup")
    }
}
