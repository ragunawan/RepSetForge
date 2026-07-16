import Foundation
import SwiftData

@MainActor
enum HistoricalSessionInvalidator {
  static func recalculate(session: WorkoutSession, in modelContext: ModelContext, rewriteHealth: Bool = true) async {
    let touchedExercises = touchedExercises(in: [session])
    rebuildPRs(for: touchedExercises, in: modelContext)
    try? modelContext.save()

    guard rewriteHealth, session.healthKitUUID != nil else { return }
    let result = await HealthKitWorkoutExporter().save(session: session)
    session.healthKitUUID = result.uuid
    try? modelContext.save()
  }

  static func delete(session: WorkoutSession, in modelContext: ModelContext, deleteHealth: Bool = true) async {
    let touchedExercises = touchedExercises(in: [session])
    if deleteHealth {
      _ = await HealthKitWorkoutExporter().delete(session: session)
    }
    modelContext.delete(session)
    rebuildPRs(for: touchedExercises, in: modelContext)
    try? modelContext.save()
  }

  static func rebuildPRs(for exercises: Set<PersistentIdentifier>, in modelContext: ModelContext) {
    guard !exercises.isEmpty else { return }

    let allRecords = (try? modelContext.fetch(FetchDescriptor<PRRecord>())) ?? []
    allRecords
      .filter { record in
        guard let exercise = record.exercise else { return false }
        return exercises.contains(exercise.persistentModelID)
      }
      .forEach(modelContext.delete)

    let allSets = (try? modelContext.fetch(FetchDescriptor<SetEntry>())) ?? []
    let groupedSets = Dictionary(grouping: allSets) { set in
      set.sessionExercise?.exercise?.persistentModelID
    }

    for exerciseID in exercises {
      let exerciseSets = (groupedSets[exerciseID] ?? [])
        .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
      guard let exercise = exerciseSets.compactMap({ $0.sessionExercise?.exercise }).first else { continue }
      PRRebuilder.rebuild(for: exercise, sets: exerciseSets).forEach(modelContext.insert)
    }
  }

  private static func touchedExercises(in sessions: [WorkoutSession]) -> Set<PersistentIdentifier> {
    Set(sessions
      .flatMap { $0.exercises ?? [] }
      .compactMap { $0.exercise?.persistentModelID })
  }
}
