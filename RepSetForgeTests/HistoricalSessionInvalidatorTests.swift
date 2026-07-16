import SwiftData
import XCTest
@testable import RepSetForge

@MainActor
final class HistoricalSessionInvalidatorTests: XCTestCase {
  func testRebuildPRsAfterHistoricalEditMovesFlagsAcrossLaterSets() throws {
    let container = try ModelContainer(
      for: ModelContainerFactory.schema,
      configurations: ModelConfiguration("HistoricalInvalidatorTests", schema: ModelContainerFactory.schema, isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let exercise = Exercise(name: "Bench Press")
    let oldSession = WorkoutSession(name: "Push", startedAt: Date(timeIntervalSince1970: 100), endedAt: Date(timeIntervalSince1970: 200), status: .completed)
    let laterSession = WorkoutSession(name: "Push", startedAt: Date(timeIntervalSince1970: 300), endedAt: Date(timeIntervalSince1970: 400), status: .completed)
    let oldExercise = SessionExercise(session: oldSession, exercise: exercise, order: 0)
    let laterExercise = SessionExercise(session: laterSession, exercise: exercise, order: 0)
    let oldSet = SetEntry(sessionExercise: oldExercise, index: 1, weightKg: 120, reps: 5, completedAt: oldSession.startedAt, isPR: true)
    let laterSet = SetEntry(sessionExercise: laterExercise, index: 1, weightKg: 110, reps: 5, completedAt: laterSession.startedAt)

    oldExercise.sets = [oldSet]
    laterExercise.sets = [laterSet]
    oldSession.exercises = [oldExercise]
    laterSession.exercises = [laterExercise]
    context.insert(exercise)
    context.insert(oldSession)
    context.insert(laterSession)

    oldSet.weightKg = 0
    oldSet.reps = 0
    HistoricalSessionInvalidator.rebuildPRs(for: [exercise.persistentModelID], in: context)

    let records = try context.fetch(FetchDescriptor<PRRecord>())
    XCTAssertTrue(laterSet.isPR)
    XCTAssertFalse(oldSet.isPR)
    XCTAssertTrue(records.contains { $0.kind == .bestWeight && $0.set === laterSet })
  }
}
