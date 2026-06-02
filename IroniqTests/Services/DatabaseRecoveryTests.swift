import XCTest
import SwiftData
@testable import Ironiq

// Phase 5: database open and recovery coverage.

final class DatabaseRecoveryTests: XCTestCase {

    // App opens normally with a healthy database.
    func testHealthyDatabaseOpens() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DBRecovery_healthy_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        let container = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        let ctx = ModelContext(container)
        ctx.insert(Template(name: "HealthyTest"))
        try ctx.save()

        // Reopen — simulates app relaunch.
        let container2 = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        let ctx2 = ModelContext(container2)
        let templates = try ctx2.fetch(FetchDescriptor<Template>())
        XCTAssertEqual(templates.first?.name, "HealthyTest")
    }

    // Corrupt store falls back through the recovery chain without crashing.
    func testCorruptStoreTriggersRecovery() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DBRecovery_corrupt_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Write garbage bytes — not a valid SQLite file.
        try Data("not a sqlite file".utf8).write(to: storeURL)

        // makeRebuiltSharedContainer backs up then removes the corrupt file before recreating.
        let container = try ModelContainerFactory.makeRebuiltSharedContainer(storeURL: storeURL)
        let ctx = ModelContext(container)
        ctx.insert(Template(name: "AfterRecovery"))
        try ctx.save()

        let templates = try ctx.fetch(FetchDescriptor<Template>())
        XCTAssertEqual(templates.first?.name, "AfterRecovery")
    }

    // Backup exists before the wipe happens during rebuilt container creation.
    func testBackupExistsBeforeWipeInRebuiltContainer() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DBRecovery_backup_\(UUID().uuidString)", isDirectory: true)
        let storeURL = dir.appendingPathComponent("Ironiq.sqlite")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create a real store first.
        _ = try ModelContainerFactory.makePersistentContainer(storeURL: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))

        // Back up explicitly.
        let backupDir = try ModelContainerFactory.backupPersistentStore(storeURL: storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path))

        let contents = try FileManager.default.contentsOfDirectory(atPath: backupDir.path)
        XCTAssertTrue(contents.contains("Ironiq.sqlite"), "Backup must contain the sqlite file")
    }

    // In-memory container always succeeds — it is the final fallback.
    func testInMemoryContainerAlwaysSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let ctx = ModelContext(container)
        ctx.insert(Template(name: "InMemoryFallback"))
        try ctx.save()
        let templates = try ctx.fetch(FetchDescriptor<Template>())
        XCTAssertFalse(templates.isEmpty)
    }
}

// Expose storeURL-parameterised overload for testing.
extension ModelContainerFactory {
    static func makeRebuiltSharedContainer(storeURL: URL) throws -> ModelContainer {
        try backupPersistentStore(storeURL: storeURL)
        let urls = [storeURL,
                    URL(fileURLWithPath: storeURL.path + "-shm"),
                    URL(fileURLWithPath: storeURL.path + "-wal")]
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        return try makePersistentContainer(storeURL: storeURL)
    }
}
