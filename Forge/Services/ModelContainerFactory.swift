import SwiftData
import Foundation

struct ModelContainerFactory {
    static func makeSharedContainer() throws -> ModelContainer {
        do {
            return try makeContainer(inMemory: false)
        } catch {
            // Store is incompatible with the current schema (e.g. after an update that
            // added/removed model properties). Wipe and recreate rather than crash-looping.
            destroyPersistentStore()
            return try makeContainer(inMemory: false)
        }
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            Template.self,
            TemplateExercise.self,
            TemplateSet.self,
            Session.self,
            SessionExercise.self,
            SessionSet.self,
            PauseRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func destroyPersistentStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: appSupport, includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.pathExtension == "sqlite"
            || file.lastPathComponent.hasSuffix(".sqlite-wal")
            || file.lastPathComponent.hasSuffix(".sqlite-shm") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
