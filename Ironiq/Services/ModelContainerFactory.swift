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
        try removePersistentStore()
        return try makeSharedContainer()
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Self.schema
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            try preparePersistentStoreDirectory()
            config = ModelConfiguration(schema: schema, url: storeURL)
        }
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func preparePersistentStoreDirectory() throws {
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
