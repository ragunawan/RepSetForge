import SwiftUI
import SwiftData

@main
struct RepSetForgeApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
