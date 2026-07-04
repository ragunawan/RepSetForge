import SwiftUI
import SwiftData

/// The watch app is a thin, read/toggle-only companion: it shows whatever
/// has already synced down via the shared CloudKit container and lets the
/// wearer log sets fast, mid-set, without pulling out their phone. It
/// deliberately does **not** seed a `PlayerCharacter`/`RPGEncounterState`/
/// achievements itself — `PersistenceController` on the phone owns that.
/// If the watch app seeded its own singleton rows before the phone's data
/// had synced down, the phone and watch would each create their own
/// `PlayerCharacter` etc., and CloudKit would merge them as two separate
/// rows instead of one — there is no "seed once" invariant CloudKit itself
/// enforces, only application code, and only the phone runs that code.
@main
struct RepSetForgeWatchApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: RepSetForgeSchemaV1.self)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        return try! ModelContainer(for: schema, migrationPlan: RepSetForgeMigrationPlan.self, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            WatchQuestView()
        }
        .modelContainer(modelContainer)
    }
}
