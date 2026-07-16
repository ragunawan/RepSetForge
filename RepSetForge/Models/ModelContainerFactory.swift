import Foundation
import SwiftData

enum ModelContainerFactory {
    static let cloudKitContainerID = "iCloud.dev.gnwn.RepSetForge"

    static var schema: Schema {
        Schema([
            Exercise.self, Routine.self, RoutineItem.self, ProgressionRule.self,
            WorkoutSession.self, SessionExercise.self, SetEntry.self,
            PRRecord.self, BodyMetric.self, UserProfile.self,
        ])
    }

    /// Production container: SwiftData + CloudKit private DB.
    static func makeShared() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// In-memory container for tests and previews; CloudKit disabled.
    static func makeEphemeral() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
