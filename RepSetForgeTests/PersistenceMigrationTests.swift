import XCTest
import SwiftData
@testable import RepSetForge

/// Proves the *pattern* future schema changes must follow: a real on-disk
/// store, opened through `RepSetForgeSchemaV1` + `RepSetForgeMigrationPlan`
/// (the exact configuration `PersistenceController` uses), saved, then
/// reopened via a brand-new `ModelContainer` instance pointed at the same
/// file — simulating an app relaunch — with every relationship intact.
/// There's only one schema version today, so this can't yet exercise an
/// actual migration *stage*; it exists so the round-trip harness is already
/// proven correct before the first real migration is ever written, per the
/// TODO item this file satisfies ("add migration tests before changing
/// SwiftData model schemas").
final class PersistenceMigrationTests: XCTestCase {
    private var storeDirectory: URL!

    override func setUpWithError() throws {
        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDirectory)
        storeDirectory = nil
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: RepSetForgeSchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, migrationPlan: RepSetForgeMigrationPlan.self, configurations: [config])
    }

    func testDataSurvivesReopeningTheStoreInABrandNewContainer() throws {
        let storeURL = storeDirectory.appendingPathComponent("Migration.store")
        let questID: UUID

        do {
            let container = try makeContainer(at: storeURL)
            let context = ModelContext(container)

            let character = PlayerCharacter(level: 5, totalXP: 800, title: "Iron Trainee", gold: 42)
            context.insert(character)

            let quest = Quest(name: "Push Day", status: .completed)
            quest.completedDate = .now
            quest.totalXP = 250
            let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.shoulders])
            exercise.sets.append(ExerciseSet(setNumber: 1, reps: 10, weight: 135, completed: true))
            quest.exercises.append(exercise)
            context.insert(quest)
            questID = quest.id

            try context.save()
        }

        // Reopen via a brand-new ModelContainer instance at the same URL —
        // simulates a real app relaunch, not just reusing the same in-memory
        // container/context the first block already had open.
        let reopened = try makeContainer(at: storeURL)
        let context = ModelContext(reopened)

        let characters = try context.fetch(FetchDescriptor<PlayerCharacter>())
        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.first?.level, 5)
        XCTAssertEqual(characters.first?.totalXP, 800)
        XCTAssertEqual(characters.first?.gold, 42)

        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests.first?.id, questID)
        XCTAssertEqual(quests.first?.name, "Push Day")
        XCTAssertEqual(quests.first?.totalXP, 250)

        let exercises = quests.first?.exercises ?? []
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.name, "Bench Press")
        XCTAssertEqual(exercises.first?.secondaryMuscles, [.shoulders])

        let sets = exercises.first?.sets ?? []
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets.first?.reps, 10)
        XCTAssertEqual(sets.first?.weight, 135)
    }

    func testMigrationPlanHasExactlyOneVersionAndNoStagesSoFar() {
        // Documents current intent — once a second schema version exists,
        // this assertion (and the migration-plan doc comment) should change
        // alongside adding a real stage and a corresponding round-trip test.
        XCTAssertEqual(RepSetForgeMigrationPlan.schemas.count, 1)
        XCTAssertTrue(RepSetForgeMigrationPlan.stages.isEmpty)
    }

    func testVersionedSchemaListsEveryPersistedModel() {
        // Guards against a model being added elsewhere (e.g. directly to
        // PersistenceController.schema) without also being added here — the
        // two must stay in sync since PersistenceController now derives its
        // schema from this versioned type.
        let modelNames = Set(RepSetForgeSchemaV1.models.map { String(describing: $0) })
        XCTAssertEqual(modelNames, [
            "Quest", "Exercise", "ExerciseSet", "ExerciseTemplate", "QuestTemplate",
            "PlayerCharacter", "MuscleProgress", "Achievement", "PersonalRecord",
            "RPGEncounterState", "OwnedEquipment", "SkillProgress"
        ])
    }
}
