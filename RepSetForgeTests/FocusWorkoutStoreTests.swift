import SwiftUI
import XCTest
@testable import RepSetForge

@MainActor
final class FocusWorkoutStoreTests: XCTestCase {
  func testCompletingUntouchedSetCommitsGhostValuesAndAppendsNextSet() {
    let store = FocusWorkoutStore(startedAt: Date(timeIntervalSince1970: 0))
    let exerciseID = store.exercises[0].id
    let setID = store.exercises[0].sets[1].id

    XCTAssertTrue(store.isGhost(.weight, set: store.exercises[0].sets[1]))

    store.complete(setID: setID, exerciseID: exerciseID, now: Date(timeIntervalSince1970: 10))

    let completed = store.exercises[0].sets[1]
    XCTAssertEqual(completed.weightKg, 60)
    XCTAssertEqual(completed.reps, 8)
    XCTAssertEqual(completed.rpe, 8)
    XCTAssertNotNil(completed.completedAt)
    XCTAssertEqual(store.exercises[0].sets.count, 4)
    XCTAssertEqual(store.completedSetCount, 1)
    XCTAssertEqual(store.draftSaveCount, 1)
  }

  func testLastSetCompletionAppendsNextInheritedRow() {
    let store = FocusWorkoutStore(startedAt: Date(timeIntervalSince1970: 0))
    let exerciseID = store.exercises[1].id
    let lastSetID = store.exercises[1].sets[2].id

    store.complete(setID: lastSetID, exerciseID: exerciseID, now: Date(timeIntervalSince1970: 5))

    XCTAssertEqual(store.exercises[1].sets.count, 4)
    XCTAssertNil(store.exercises[1].sets[3].weightKg)
    XCTAssertEqual(store.displayWeight(for: store.exercises[1].sets[3], in: store.exercises[1]), 92.5)
  }

  func testChartCollapsesOnFirstCompletedSetAndCanReopen() {
    let store = FocusWorkoutStore()
    let exercise = store.exercises[0]
    let setID = exercise.sets[0].id

    XCTAssertTrue(store.isChartExpanded(for: exercise))

    store.complete(setID: setID, exerciseID: exercise.id)

    XCTAssertFalse(store.isChartExpanded(for: store.exercises[0]))
    store.setChartExpanded(true, for: store.exercises[0])
    XCTAssertTrue(store.isChartExpanded(for: store.exercises[0]))
  }

  func testRestLedgerKeepsWorkAndRestWithinSessionDuration() {
    let store = FocusWorkoutStore(startedAt: Date(timeIntervalSince1970: 0))
    let exercise = store.exercises[0]

    store.complete(setID: exercise.sets[0].id, exerciseID: exercise.id, now: Date(timeIntervalSince1970: 10))
    store.skipRest(now: Date(timeIntervalSince1970: 40))

    XCTAssertEqual(store.completedRestDuration, 30)
    XCTAssertEqual(store.workDuration(now: Date(timeIntervalSince1970: 100)) + store.completedRestDuration, 100, accuracy: 0.001)
  }

  func testPRFlagIsInlineDerivedOnCommit() {
    let store = FocusWorkoutStore()
    let exerciseID = store.exercises[0].id
    let setID = store.exercises[0].sets[1].id

    store.step(.weight, setID: setID, exerciseID: exerciseID, direction: 18)
    store.complete(setID: setID, exerciseID: exerciseID)

    XCTAssertTrue(store.exercises[0].sets[1].isPR)
  }

  func testFocusViewRendersAtRequiredTypeSizesAndColorSchemes() throws {
    let sizes: [DynamicTypeSize] = [.large, .xxxLarge, .accessibility1, .accessibility3]
    let schemes: [ColorScheme] = [.light, .dark]

    for size in sizes {
      for scheme in schemes {
        let renderer = ImageRenderer(content:
          FocusWorkoutView(store: FocusWorkoutStore())
            .environment(\.dynamicTypeSize, size)
            .preferredColorScheme(scheme)
            .frame(width: 393, height: 852)
        )
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, "Expected render for \(size) \(scheme)")
        XCTAssertEqual(image.size.width, 393)
        XCTAssertEqual(image.size.height, 852)
      }
    }
  }
}
