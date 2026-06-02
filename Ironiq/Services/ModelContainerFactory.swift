import SwiftData
import Foundation

struct ModelContainerFactory {
    private static let storeFileName = "Ironiq.sqlite"

    private static var schema: Schema {
        Schema([
            Exercise.self,
            Template.self,
            TemplateExercise.self,
            TemplateSet.self,
            Session.self,
            SessionExercise.self,
            SessionSet.self,
            PauseRecord.self
        ])
    }

    private static var storeURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ironiq", isDirectory: true)
            .appendingPathComponent(storeFileName)
    }

    static func makeSharedContainer() throws -> ModelContainer {
        try makeContainer(inMemory: false)
    }

    static func makeRebuiltSharedContainer() throws -> ModelContainer {
        try backupPersistentStore()
        try removePersistentStore()
        return try makeSharedContainer()
    }

    // Backs up the production store. Returns backup directory URL.
    @discardableResult
    static func backupPersistentStore() throws -> URL {
        try backupPersistentStore(storeURL: storeURL)
    }

    // Exposed with explicit storeURL so tests can pass a temporary path.
    @discardableResult
    static func backupPersistentStore(storeURL: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: Date())
        let backupDir = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent(timestamp, isDirectory: true)

        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let filesToBackup = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for url in filesToBackup where FileManager.default.fileExists(atPath: url.path) {
            let dest = backupDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: dest)
        }
        return backupDir
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        if inMemory {
            let schema = Self.schema
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        }
        return try makePersistentContainer(storeURL: storeURL)
    }

    static func makePersistentContainer(storeURL: URL) throws -> ModelContainer {
        let schema = Self.schema
        try preparePersistentStoreDirectory(for: storeURL)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func preparePersistentStoreDirectory() throws {
        try preparePersistentStoreDirectory(for: storeURL)
    }

    private static func preparePersistentStoreDirectory(for storeURL: URL) throws {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func removePersistentStore() throws {
        try preparePersistentStoreDirectory()
        let urls = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
