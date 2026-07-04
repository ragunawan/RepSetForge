import XCTest
import SwiftData
@testable import RepSetForge

final class ProgressImportServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self, PersonalRecord.self, SkillProgress.self, OwnedEquipment.self, RPGEncounterState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        context.insert(PlayerCharacter())
        for group in MuscleGroup.allCases {
            context.insert(MuscleProgress(muscleGroup: group))
        }
        for achievement in AchievementService.seedDefinitions() {
            context.insert(achievement)
        }
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private func exportedQuest(id: UUID = UUID(), name: String, daysAgo: Int, reps: Int = 10, weight: Double = 100) -> ProgressExport.QuestExport {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let set = ProgressExport.SetExport(setNumber: 1, reps: reps, weight: weight, weightUnit: "lb", distanceMiles: 0, durationSeconds: 0, completed: true)
        let exercise = ProgressExport.ExerciseExport(name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["arms"], exerciseType: "strength", sets: [set])
        return ProgressExport.QuestExport(id: id, name: name, date: date, status: "Completed", completedDate: date, totalXP: 0, notes: "", perceivedEffort: nil, exercises: [exercise])
    }

    private func exportData(quests: [ProgressExport.QuestExport]) throws -> Data {
        let export = ProgressExport(exportedDate: .now, character: nil, muscles: [], quests: quests, personalRecords: [], achievements: [])
        return try ProgressExportService.json(from: export)
    }

    func testImportInsertsNewQuests() throws {
        let data = try exportData(quests: [exportedQuest(name: "Push Day", daysAgo: 1)])
        let result = try ProgressImportService.importExport(from: data, context: context)

        XCTAssertEqual(result.importedQuestCount, 1)
        XCTAssertEqual(result.skippedDuplicateQuestCount, 0)

        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests.first?.name, "Push Day")
        XCTAssertEqual(quests.first?.exercises.first?.name, "Bench Press")
        XCTAssertEqual(quests.first?.exercises.first?.primaryMuscle, .chest)
        XCTAssertEqual(quests.first?.exercises.first?.sets.first?.reps, 10)
    }

    func testImportRecomputesCharacterXPFromImportedQuests() throws {
        let data = try exportData(quests: [exportedQuest(name: "Push Day", daysAgo: 1, reps: 10, weight: 100)])
        _ = try ProgressImportService.importExport(from: data, context: context)

        let character = try XCTUnwrap(context.fetch(FetchDescriptor<PlayerCharacter>()).first)
        XCTAssertGreaterThan(character.totalXP, 0)
    }

    func testReimportingSameFileSkipsDuplicates() throws {
        let id = UUID()
        let data = try exportData(quests: [exportedQuest(id: id, name: "Push Day", daysAgo: 1)])

        let first = try ProgressImportService.importExport(from: data, context: context)
        XCTAssertEqual(first.importedQuestCount, 1)

        let second = try ProgressImportService.importExport(from: data, context: context)
        XCTAssertEqual(second.importedQuestCount, 0)
        XCTAssertEqual(second.skippedDuplicateQuestCount, 1)

        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 1)
    }

    func testImportOfOverlappingExportsOnlyAddsNewOnes() throws {
        let sharedID = UUID()
        let firstData = try exportData(quests: [exportedQuest(id: sharedID, name: "Push Day", daysAgo: 5)])
        _ = try ProgressImportService.importExport(from: firstData, context: context)

        let secondData = try exportData(quests: [
            exportedQuest(id: sharedID, name: "Push Day", daysAgo: 5),
            exportedQuest(name: "Leg Day", daysAgo: 1)
        ])
        let result = try ProgressImportService.importExport(from: secondData, context: context)

        XCTAssertEqual(result.importedQuestCount, 1)
        XCTAssertEqual(result.skippedDuplicateQuestCount, 1)
        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 2)
    }

    func testInvalidDataThrows() {
        let garbage = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try ProgressImportService.importExport(from: garbage, context: context)) { error in
            XCTAssertTrue(error is ProgressImportError)
        }
    }

    func testFutureDatedNonCompletedQuestImportsAsPlanned() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let set = ProgressExport.SetExport(setNumber: 1, reps: 10, weight: 100, weightUnit: "lb", distanceMiles: 0, durationSeconds: 0, completed: false)
        let exercise = ProgressExport.ExerciseExport(name: "Squat", primaryMuscle: "legs", secondaryMuscles: [], exerciseType: "strength", sets: [set])
        let questExport = ProgressExport.QuestExport(id: UUID(), name: "Future Quest", date: futureDate, status: "Planned", completedDate: nil, totalXP: 0, notes: "", perceivedEffort: nil, exercises: [exercise])
        let data = try exportData(quests: [questExport])

        _ = try ProgressImportService.importExport(from: data, context: context)
        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.first?.status, .planned)
    }
}
