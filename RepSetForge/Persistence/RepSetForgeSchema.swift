import Foundation
import SwiftData

enum RepSetForgeSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Routine.self,
            RoutineItem.self,
            ProgressionRule.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetEntry.self,
            PRRecord.self,
            BodyMetric.self,
        ]
    }
}

enum RepSetForgeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RepSetForgeSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
