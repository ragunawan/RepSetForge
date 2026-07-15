import Foundation
import SwiftData

enum PersistenceController {
    /// CloudKit-backed private-database container with automatic local fallback
    /// when no iCloud account is available (CLAUDE.md).
    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: RepSetForgeSchemaV1.self)

        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.dev.gnwn.RepSetForge")
        )

        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: RepSetForgeMigrationPlan.self,
            configurations: [cloudConfiguration]
        ) {
            return container
        }

        // No iCloud account, CloudKit unavailable, or container creation
        // otherwise failed — fall back to a local-only store.
        let localConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RepSetForgeMigrationPlan.self,
                configurations: [localConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer even without CloudKit: \(error)")
        }
    }
}
