import Foundation
import SwiftData

/// The current on-disk model set, versioned via SwiftData's
/// `VersionedSchema`/`SchemaMigrationPlan` so a future schema change has a
/// clear, already-proven place to slot in — rather than discovering the
/// migration APIs for the first time under deadline pressure once a real
/// breaking change (renaming/removing a property, changing a type,
/// splitting a model) is needed. Every `@Model` type must be listed here,
/// not just wherever it's used, or SwiftData won't know it belongs to this
/// versioned schema.
enum RepSetForgeSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Quest.self,
            Exercise.self,
            ExerciseSet.self,
            ExerciseTemplate.self,
            QuestTemplate.self,
            PlayerCharacter.self,
            MuscleProgress.self,
            Achievement.self,
            PersonalRecord.self,
            RPGEncounterState.self,
            OwnedEquipment.self,
            SkillProgress.self
        ]
    }
}

/// Empty for now — there's only one schema version, so there's nothing to
/// migrate *from* yet. When a future change needs an explicit migration:
///   1. Add a new `RepSetForgeSchemaV2: VersionedSchema` enum with the
///      updated `models` list.
///   2. Append it to `schemas` below.
///   3. Add a `.lightweight` (additive/renamed-with-mapping) or `.custom`
///      (anything requiring hand-written transformation) `MigrationStage`
///      to `stages` describing how V1 becomes V2.
///   4. Add a test to `PersistenceMigrationTests` that builds a real
///      on-disk store at V1, saves representative data, then reopens it
///      through this plan and confirms the V2 data is correct — *before*
///      shipping the change, per the TODO item this file exists to satisfy.
enum RepSetForgeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RepSetForgeSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
