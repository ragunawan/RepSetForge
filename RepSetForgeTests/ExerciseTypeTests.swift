import XCTest
@testable import RepSetForge

final class ExerciseTypeTests: XCTestCase {

    func testStrengthTracksRepsAndWeightOnly() {
        XCTAssertTrue(ExerciseType.strength.tracksReps)
        XCTAssertTrue(ExerciseType.strength.tracksWeight)
        XCTAssertFalse(ExerciseType.strength.tracksDistance)
        XCTAssertFalse(ExerciseType.strength.tracksDuration)
    }

    func testBodyweightTracksRepsOnly() {
        XCTAssertTrue(ExerciseType.bodyweight.tracksReps)
        XCTAssertFalse(ExerciseType.bodyweight.tracksWeight)
        XCTAssertFalse(ExerciseType.bodyweight.tracksDistance)
        XCTAssertFalse(ExerciseType.bodyweight.tracksDuration)
    }

    func testAssistedTracksRepsAndWeight() {
        XCTAssertTrue(ExerciseType.assisted.tracksReps)
        XCTAssertTrue(ExerciseType.assisted.tracksWeight)
    }

    func testDistanceTracksDistanceOnly() {
        XCTAssertFalse(ExerciseType.distance.tracksReps)
        XCTAssertFalse(ExerciseType.distance.tracksWeight)
        XCTAssertTrue(ExerciseType.distance.tracksDistance)
        XCTAssertFalse(ExerciseType.distance.tracksDuration)
    }

    func testDurationTracksDurationOnly() {
        XCTAssertFalse(ExerciseType.duration.tracksReps)
        XCTAssertFalse(ExerciseType.duration.tracksDistance)
        XCTAssertTrue(ExerciseType.duration.tracksDuration)
    }

    func testCardioTracksDistanceAndDuration() {
        XCTAssertFalse(ExerciseType.cardio.tracksReps)
        XCTAssertFalse(ExerciseType.cardio.tracksWeight)
        XCTAssertTrue(ExerciseType.cardio.tracksDistance)
        XCTAssertTrue(ExerciseType.cardio.tracksDuration)
    }

    func testExerciseDefaultsToStrengthType() {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        XCTAssertEqual(exercise.exerciseType, .strength)
    }

    func testExerciseCanBeAssignedANonStrengthType() {
        let exercise = Exercise(name: "Plank", primaryMuscle: .core, exerciseType: .duration)
        XCTAssertEqual(exercise.exerciseType, .duration)
    }
}
