import SwiftData

struct ModelContainerFactory {
    static func makeSharedContainer() throws -> ModelContainer {
        try makeContainer(inMemory: false)
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
}
