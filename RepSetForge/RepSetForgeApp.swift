import SwiftUI
import SwiftData

@main
struct RepSetForgeApp: App {
    let container: ModelContainer
    /// §6 theme: light/dark/system, applied app-wide.
    @AppStorage("themePreference") private var themePreference = "system"

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
                .preferredColorScheme(themePreference == "light" ? .light
                                      : themePreference == "dark" ? .dark : nil)
        }
        .modelContainer(container)
    }
}
