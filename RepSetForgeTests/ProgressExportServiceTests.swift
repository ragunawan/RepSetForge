import XCTest
@testable import RepSetForge

final class ProgressExportServiceTests: XCTestCase {

    private func quest(name: String, exercises: [Exercise] = []) -> Quest {
        let quest = Quest(name: name, status: .completed)
        quest.totalXP = 100
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(name: String, sets: [(reps: Int, weight: Double)]) -> Exercise {
        let exercise = Exercise(name: name, primaryMuscle: .chest)
        for (index, set) in sets.enumerated() {
            exercise.sets.append(ExerciseSet(setNumber: index + 1, reps: set.reps, weight: set.weight, completed: true))
        }
        return exercise
    }

    func testMakeExportWithNoDataProducesEmptyCollections() {
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [], personalRecords: [], achievements: [])
        XCTAssertNil(export.character)
        XCTAssertTrue(export.muscles.isEmpty)
        XCTAssertTrue(export.quests.isEmpty)
        XCTAssertTrue(export.personalRecords.isEmpty)
        XCTAssertTrue(export.achievements.isEmpty)
    }

    func testMakeExportIncludesCharacterSummary() {
        let character = PlayerCharacter(level: 5, totalXP: 1200, title: "Iron Trainee", completedQuestCount: 8, gold: 42)
        let export = ProgressExportService.makeExport(character: character, muscles: [], quests: [], personalRecords: [], achievements: [])
        XCTAssertEqual(export.character?.level, 5)
        XCTAssertEqual(export.character?.totalXP, 1200)
        XCTAssertEqual(export.character?.title, "Iron Trainee")
        XCTAssertEqual(export.character?.gold, 42)
    }

    func testMakeExportPreservesExerciseAndSetStructure() {
        let bench = exercise(name: "Bench Press", sets: [(10, 100), (8, 110)])
        let q = quest(name: "Push Day", exercises: [bench])
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [q], personalRecords: [], achievements: [])

        XCTAssertEqual(export.quests.count, 1)
        XCTAssertEqual(export.quests.first?.exercises.count, 1)
        XCTAssertEqual(export.quests.first?.exercises.first?.sets.count, 2)
        XCTAssertEqual(export.quests.first?.exercises.first?.sets.first?.reps, 10)
    }

    func testJSONIsValidAndDecodable() throws {
        let q = quest(name: "Leg Day", exercises: [exercise(name: "Squat", sets: [(10, 185)])])
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [q], personalRecords: [], achievements: [])
        let data = try ProgressExportService.json(from: export)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProgressExport.self, from: data)
        XCTAssertEqual(decoded.quests.first?.name, "Leg Day")
    }

    func testCSVHasHeaderRowPlusOneRowPerSet() {
        let bench = exercise(name: "Bench Press", sets: [(10, 100), (8, 110)])
        let squat = exercise(name: "Squat", sets: [(5, 200)])
        let q = quest(name: "Full Body", exercises: [bench, squat])
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [q], personalRecords: [], achievements: [])

        let csv = ProgressExportService.csv(from: export)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 4) // header + 3 sets
        XCTAssertTrue(lines[0].contains("Quest Name"))
    }

    func testCSVEscapesFieldsContainingCommas() {
        let q = quest(name: "Push, Pull & Legs", exercises: [exercise(name: "Bench Press", sets: [(10, 100)])])
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [q], personalRecords: [], achievements: [])
        let csv = ProgressExportService.csv(from: export)
        XCTAssertTrue(csv.contains("\"Push, Pull & Legs\""))
    }

    func testCSVEscapesFieldsContainingQuotes() {
        let q = quest(name: "The \"Big\" Day", exercises: [exercise(name: "Bench Press", sets: [(10, 100)])])
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [q], personalRecords: [], achievements: [])
        let csv = ProgressExportService.csv(from: export)
        XCTAssertTrue(csv.contains("\"The \"\"Big\"\" Day\""))
    }

    func testCSVWithNoQuestsIsJustTheHeaderRow() {
        let export = ProgressExportService.makeExport(character: nil, muscles: [], quests: [], personalRecords: [], achievements: [])
        let csv = ProgressExportService.csv(from: export)
        XCTAssertEqual(csv.split(separator: "\n").count, 1)
    }
}
