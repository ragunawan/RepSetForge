import SwiftUI
import SwiftData

@main
struct RepSetForgeApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistence.modelContainer)
    }
}
