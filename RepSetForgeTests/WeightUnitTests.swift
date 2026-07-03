import XCTest
@testable import RepSetForge

final class WeightUnitTests: XCTestCase {

    func testConvertingToSameUnitIsANoOp() {
        XCTAssertEqual(WeightUnit.pounds.convert(185, to: .pounds), 185)
        XCTAssertEqual(WeightUnit.kilograms.convert(84, to: .kilograms), 84)
    }

    func testConvertsPoundsToKilograms() {
        let kg = WeightUnit.pounds.convert(220.462, to: .kilograms)
        XCTAssertEqual(kg, 100, accuracy: 0.01)
    }

    func testConvertsKilogramsToPounds() {
        let lb = WeightUnit.kilograms.convert(100, to: .pounds)
        XCTAssertEqual(lb, 220.462, accuracy: 0.01)
    }

    func testFormattedIncludesAbbreviation() {
        XCTAssertEqual(WeightUnit.pounds.formatted(185), "185.0 lb")
        XCTAssertEqual(WeightUnit.kilograms.formatted(84), "84.0 kg")
    }

    func testExerciseSetDefaultsToPounds() {
        let set = ExerciseSet(setNumber: 1, weight: 100)
        XCTAssertEqual(set.weightUnit, .pounds)
    }

    func testExerciseSetCanBeLoggedInKilograms() {
        let set = ExerciseSet(setNumber: 1, weight: 60, weightUnit: .kilograms)
        XCTAssertEqual(set.weightUnit, .kilograms)
        XCTAssertEqual(set.weight, 60)
    }

    func testPlayerCharacterDefaultsToPoundsPreference() {
        let character = PlayerCharacter()
        XCTAssertEqual(character.preferredWeightUnit, .pounds)
    }

    func testPlayerCharacterPreferenceIsMutable() {
        let character = PlayerCharacter()
        character.preferredWeightUnit = .kilograms
        XCTAssertEqual(character.preferredWeightUnit, .kilograms)
    }
}
