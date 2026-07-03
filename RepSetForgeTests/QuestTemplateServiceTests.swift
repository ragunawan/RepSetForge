import XCTest
@testable import RepSetForge

final class QuestTemplateServiceTests: XCTestCase {

    func testMakeQuestCopiesTemplateName() {
        let template = QuestTemplate(name: "Push Day")

        let quest = QuestTemplateService.makeQuest(from: template)

        XCTAssertEqual(quest.name, "Push Day")
        XCTAssertEqual(quest.status, .active)
    }

    func testMakeQuestBuildsOneExercisePerBlueprint() {
        let bench = QuestExerciseBlueprint(
            name: "Bench Press",
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .arms],
            notes: "Pause at chest",
            defaultSetCount: 3,
            defaultReps: 8,
            defaultWeight: 135,
            defaultRestSeconds: 90
        )
        let overheadPress = QuestExerciseBlueprint(name: "Overhead Press", primaryMuscle: .shoulders, defaultSetCount: 4, defaultReps: 6, defaultWeight: 95)
        let template = QuestTemplate(name: "Push Day", exerciseBlueprints: [bench, overheadPress])

        let quest = QuestTemplateService.makeQuest(from: template)

        XCTAssertEqual(quest.exercises.count, 2)
        XCTAssertEqual(quest.exercises[0].name, "Bench Press")
        XCTAssertEqual(quest.exercises[0].primaryMuscle, .chest)
        XCTAssertEqual(Set(quest.exercises[0].secondaryMuscles), [.shoulders, .arms])
        XCTAssertEqual(quest.exercises[0].notes, "Pause at chest")
        XCTAssertEqual(quest.exercises[0].sets.count, 3)
        XCTAssertEqual(quest.exercises[0].sets.map(\.setNumber), [1, 2, 3])
        XCTAssertTrue(quest.exercises[0].sets.allSatisfy { $0.reps == 8 && $0.weight == 135 && !$0.completed })
        XCTAssertEqual(quest.exercises[0].defaultRestSeconds, 90)

        XCTAssertEqual(quest.exercises[1].name, "Overhead Press")
        XCTAssertEqual(quest.exercises[1].sets.count, 4)
    }

    func testMakeQuestWithZeroSetCountBlueprintCreatesNoSets() {
        let blueprint = QuestExerciseBlueprint(name: "Plank", primaryMuscle: .core, defaultSetCount: 0)
        let template = QuestTemplate(name: "Core Trial", exerciseBlueprints: [blueprint])

        let quest = QuestTemplateService.makeQuest(from: template)

        XCTAssertTrue(quest.exercises[0].sets.isEmpty)
    }

    func testMakeTemplateSnapshotsExerciseFieldsAndFirstSet() {
        let exercise = Exercise(name: "Rows", primaryMuscle: .back, secondaryMuscles: [.arms], notes: "Keep elbows tucked", defaultRestSeconds: 75)
        exercise.sets = [
            ExerciseSet(setNumber: 1, reps: 10, weight: 95, completed: true),
            ExerciseSet(setNumber: 2, reps: 8, weight: 100),
        ]

        let template = QuestTemplateService.makeTemplate(name: "Pull Day", exercises: [exercise])

        XCTAssertEqual(template.name, "Pull Day")
        XCTAssertEqual(template.exerciseBlueprints.count, 1)
        let blueprint = template.exerciseBlueprints[0]
        XCTAssertEqual(blueprint.name, "Rows")
        XCTAssertEqual(blueprint.primaryMuscle, .back)
        XCTAssertEqual(blueprint.secondaryMuscles, [.arms])
        XCTAssertEqual(blueprint.notes, "Keep elbows tucked")
        XCTAssertEqual(blueprint.defaultSetCount, 2)
        XCTAssertEqual(blueprint.defaultReps, 10)
        XCTAssertEqual(blueprint.defaultWeight, 95)
        XCTAssertEqual(blueprint.defaultRestSeconds, 75)
    }

    func testMakeTemplateFallsBackToDefaultsWhenExerciseHasNoSets() {
        let exercise = Exercise(name: "Plank", primaryMuscle: .core)

        let template = QuestTemplateService.makeTemplate(name: "Core Trial", exercises: [exercise])

        let blueprint = template.exerciseBlueprints[0]
        XCTAssertEqual(blueprint.defaultSetCount, 0)
        XCTAssertEqual(blueprint.defaultReps, 10)
        XCTAssertEqual(blueprint.defaultWeight, 0)
    }

    func testBlueprintDecodingDefaultsRestSecondsWhenMissingFromOlderSavedData() throws {
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Old Blueprint",
            "primaryMuscleRaw": "chest",
            "secondaryMuscleRawValues": [],
            "notes": "",
            "defaultSetCount": 3,
            "defaultReps": 10,
            "defaultWeight": 0
        }
        """
        let blueprint = try JSONDecoder().decode(QuestExerciseBlueprint.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(blueprint.name, "Old Blueprint")
        XCTAssertEqual(blueprint.defaultRestSeconds, 60)
    }
}
