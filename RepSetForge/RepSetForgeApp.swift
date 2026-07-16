import SwiftUI
import SwiftData

@main
struct RepSetForgeApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeShared()
        } catch {
            // CloudKit config can fail (no entitlement in some dev contexts);
            // fall back to a local ephemeral store rather than crashing.
            container = try! ModelContainerFactory.makeEphemeral()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
