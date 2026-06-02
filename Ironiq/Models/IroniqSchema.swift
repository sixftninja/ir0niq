import SwiftData

// Versioned schema for Ironiq's SwiftData store.
//
// Every time a SwiftData model property is added, removed, or renamed:
//   1. Add a new VersionedSchema (IroniqSchemaV2, V3, …) with the updated models.
//   2. Add a MigrationStage to IroniqMigrationPlan describing the change.
//   3. Update ModelContainerFactory to reference the new plan.
//
// This ensures future schema changes use SwiftData's migration path instead of
// triggering the destructive recovery path in ModelContainerFactory.

enum IroniqSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Template.self,
            TemplateExercise.self,
            TemplateSet.self,
            Session.self,
            SessionExercise.self,
            SessionSet.self,
            PauseRecord.self,
        ]
    }
}

enum IroniqMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [IroniqSchemaV1.self] }
    // No migration stages yet — V1 is the initial version.
    // Add .lightweight or .custom stages here when a V2 is introduced.
    static var stages: [MigrationStage] { [] }
}
