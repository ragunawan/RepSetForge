import XCTest
@testable import RepSetForge

final class LadderEngineTests: XCTestCase {
  func testLadderAdvancesThroughRepRangeAndRegeneratesAtIncrementedWeight() {
    let rule = ProgressionRuleSnapshot(repRangeLow: 8, repRangeHigh: 10, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
    let sets = [
      set(weight: 100, reps: 8, rpe: 8, time: 10),
      set(weight: 100, reps: 8, rpe: 8.5, time: 20),
      set(weight: 100, reps: 9, rpe: 8, time: 30),
      set(weight: 100, reps: 9, rpe: 9, time: 40),
      set(weight: 100, reps: 10, rpe: 8, time: 50),
      set(weight: 100, reps: 10, rpe: 8, time: 60),
    ]

    let state = LadderEngine.rebuild(rule: rule, baseWeightKg: 100, sets: sets)

    XCTAssertEqual(state.currentLevel.weightKg, 102.5)
    XCTAssertEqual(state.currentLevel.reps, 8)
    XCTAssertEqual(state.levels.map(\.reps), [8, 9, 10])
  }

  func testLadderRegressesWhenHistoricalQualifyingSetIsInvalidated() {
    let rule = ProgressionRuleSnapshot(repRangeLow: 8, repRangeHigh: 9, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
    let sets = [
      set(weight: 80, reps: 8, rpe: 8, time: 10),
      set(weight: 80, reps: 8, rpe: 8, time: 20),
      set(weight: 80, reps: 9, rpe: 8, time: 30),
      set(weight: 80, reps: 9, rpe: 9.5, time: 40),
    ]

    let state = LadderEngine.rebuild(rule: rule, baseWeightKg: 80, sets: sets)

    XCTAssertEqual(state.currentLevel.weightKg, 80)
    XCTAssertEqual(state.currentLevel.reps, 9)
  }

  @MainActor
  func testPromptTargetEqualsLadderHeadAfterSetCompletion() {
    let store = FocusWorkoutStore(startedAt: Date(timeIntervalSince1970: 0))
    let exerciseID = store.exercises[0].id
    let firstWorking = store.exercises[0].sets[1].id
    let secondWorking = store.exercises[0].sets[2].id

    store.complete(setID: firstWorking, exerciseID: exerciseID, now: Date(timeIntervalSince1970: 10))
    store.complete(setID: secondWorking, exerciseID: exerciseID, now: Date(timeIntervalSince1970: 20))

    let exercise = store.exercises[0]
    XCTAssertEqual(exercise.targetWeightKg, exercise.ladderState.currentLevel.weightKg)
    XCTAssertEqual(exercise.targetReps, exercise.ladderState.currentLevel.reps)
  }

  func testLadderIsRegenerableForGeneratedHistories() {
    let rule = ProgressionRuleSnapshot(repRangeLow: 6, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 5)

    for completedLevelCount in 0...7 {
      var sets: [SetEntry] = []
      var weight: Decimal = 60
      var reps = 6
      for level in 0..<completedLevelCount {
        sets.append(set(weight: weight, reps: reps, rpe: 8, time: TimeInterval(level * 10 + 1)))
        sets.append(set(weight: weight, reps: reps, rpe: 8.5, time: TimeInterval(level * 10 + 2)))
        if reps == 8 {
          weight += 5
          reps = 6
        } else {
          reps += 1
        }
      }

      let first = LadderEngine.rebuild(rule: rule, baseWeightKg: 60, sets: sets)
      let second = LadderEngine.rebuild(rule: rule, baseWeightKg: 60, sets: sets.shuffled())

      XCTAssertEqual(first.currentLevel, second.currentLevel)
      XCTAssertEqual(first.levels, second.levels)
    }
  }

  private func set(weight: Decimal, reps: Int, rpe: Decimal, time: TimeInterval) -> SetEntry {
    SetEntry(
      index: Int(time),
      type: .working,
      weightKg: weight,
      reps: reps,
      rpe: rpe,
      completedAt: Date(timeIntervalSince1970: time)
    )
  }
}
