import SwiftUI
import SwiftData

@main
struct RepSetForgeApp: App {
  private let modelContainer = ModelContainerFactory.live()

  var body: some Scene {
    WindowGroup {
      RootView()
        .preferredColorScheme(nil)
        .modelContainer(modelContainer)
    }
  }
}
