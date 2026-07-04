import Foundation
import SwiftData

/// Where the app family shares its data: the CloudKit container identifier
/// (declared in each target's own entitlements) plus, for extensions that
/// need a fast synchronous read within a strict execution budget (the
/// widget's timeline provider), an App Group–shared local store location.
///
/// Shared by the phone app and the widget extension — **not** the watch
/// app, which has no App Group entitlement and reaches the store purely
/// via CloudKit sync, since it's a companion device rather than a
/// same-device extension.
enum SharedStore {
    static let appGroupIdentifier = "group.dev.gnwn.RepSetForge"

    static func containerURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: "default.store")
    }

    /// A container for code that only ever reads (the widget's timeline
    /// provider): never seeds anything, unlike `PersistenceController` —
    /// seeding is the phone app's job alone, for the same reason the watch
    /// app doesn't seed either (see `RepSetForgeWatchApp`'s doc comment).
    static func makeReadOnlyContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: RepSetForgeSchemaV1.self)
        let config: ModelConfiguration
        if let url = containerURL() {
            config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
        } else {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        }
        return try! ModelContainer(for: schema, migrationPlan: RepSetForgeMigrationPlan.self, configurations: [config])
    }
}
