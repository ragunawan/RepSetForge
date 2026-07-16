import Foundation
import SwiftData

enum ModelContainerFactory {
  static let schema = Schema([
    Exercise.self,
    Routine.self,
    RoutineItem.self,
    ProgressionRule.self,
    WorkoutSession.self,
    SessionExercise.self,
    SetEntry.self,
    PRRecord.self,
    BodyMetric.self,
    UserProfile.self,
  ])

  @MainActor
  static func live() -> ModelContainer {
    do {
      let configuration: ModelConfiguration
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        configuration = ModelConfiguration("RepSetForgeTests", schema: schema, isStoredInMemoryOnly: true)
      } else {
        configuration = ModelConfiguration(
          "RepSetForge",
          schema: schema,
          cloudKitDatabase: .private("iCloud.com.repsetforge.app")
        )
      }
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Failed to create SwiftData container: \(error)")
    }
  }
}
