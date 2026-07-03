import XCTest
import SwiftData
@testable import RepSetForge

final class ProgressionRebuildServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var character: PlayerCharacter!
    var muscles: [MuscleProgress]!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        character = PlayerCharacter()
        context.insert(character)
        muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        muscles.forEach { context.insert($0) }
        for achievement in AchievementService.seedDefinitions() {
            context.insert(achievement)
        }
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private func completedQuest(name: String, reps: Int, weight: Double, daysAgo: Int) -> Quest {
        let quest = Quest(name: name, status: .completed)
        quest.completedDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true)]
        quest.exercises = [exercise]
        context.insert(quest)
        return quest
    }

    func testRebuildIgnoresNonCompletedQuests() throws {
        _ = completedQuest(name: "Done", reps: 5, weight: 100, daysAgo: 1)
        let planned = Quest(name: "Planned", status: .planned)
        let plannedExercise = Exercise(name: "Squat", primaryMuscle: .legs)
        plannedExercise.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 200, completed: true)]
        planned.exercises = [plannedExercise]
        context.insert(planned)
        try context.save()

        ProgressionRebuildService.rebuild(context: context)

        XCTAssertEqual(character.completedQuestCount, 1)
        let legs = try XCTUnwrap(muscles.first { $0.muscleGroup == .legs })
        XCTAssertEqual(legs.totalXP, 0)
    }

    func testRebuildMatchesSingleQuestCompletion() throws {
        _ = completedQuest(name: "Push Day", reps: 5, weight: 185, daysAgo: 0)
        try context.save()

        let expectedXP = ProgressionService.setXP(reps: 5, weight: 185)

        ProgressionRebuildService.rebuild(context: context)

        XCTAssertEqual(character.totalXP, expectedXP)
        XCTAssertEqual(character.completedQuestCount, 1)
        let chest = try XCTUnwrap(muscles.first { $0.muscleGroup == .chest })
        XCTAssertEqual(chest.totalXP, expectedXP)
    }

    func testRebuildIsIdempotent() throws {
        _ = completedQuest(name: "Push Day", reps: 5, weight: 185, daysAgo: 2)
        _ = completedQuest(name: "Pull Day", reps: 8, weight: 135, daysAgo: 1)
        try context.save()

        ProgressionRebuildService.rebuild(context: context)
        let firstTotalXP = character.totalXP
        let firstQuestCount = character.completedQuestCount

        ProgressionRebuildService.rebuild(context: context)

        XCTAssertEqual(character.totalXP, firstTotalXP)
        XCTAssertEqual(character.completedQuestCount, firstQuestCount)
    }

    func testUndoingCompletionRemovesItsContributionWithoutAffectingOthers() throws {
        let keep = completedQuest(name: "Keep", reps: 5, weight: 185, daysAgo: 2)
        let undone = completedQuest(name: "Undo Me", reps: 8, weight: 135, daysAgo: 1)
        try context.save()

        ProgressionRebuildService.rebuild(context: context)
        let keepXP = ProgressionService.setXP(reps: 5, weight: 185)
        let undoneXP = ProgressionService.setXP(reps: 8, weight: 135)
        XCTAssertEqual(character.totalXP, keepXP + undoneXP)

        // Mirrors QuestDetailView.undoCompletion()
        undone.status = .active
        undone.completedDate = nil
        undone.totalXP = 0
        ProgressionRebuildService.rebuild(context: context)

        XCTAssertEqual(character.totalXP, keepXP)
        XCTAssertEqual(character.completedQuestCount, 1)
        XCTAssertEqual(keep.totalXP, keepXP)
    }

    func testEditingCompletedQuestSetsChangesRecalculatedXPOnRebuild() throws {
        let quest = completedQuest(name: "Push Day", reps: 5, weight: 185, daysAgo: 0)
        try context.save()

        quest.exercises[0].sets[0].reps = 10

        ProgressionRebuildService.rebuild(context: context)

        let expectedXP = ProgressionService.setXP(reps: 10, weight: 185)
        XCTAssertEqual(quest.totalXP, expectedXP)
        XCTAssertEqual(character.totalXP, expectedXP)
    }

    func testRebuildReDerivesAchievementsFromRemainingHistory() throws {
        let onlyQuest = completedQuest(name: "Only Quest", reps: 5, weight: 100, daysAgo: 0)
        try context.save()

        ProgressionRebuildService.rebuild(context: context)
        let achievementsAfterFirst = try context.fetch(FetchDescriptor<Achievement>())
        XCTAssertTrue(achievementsAfterFirst.first { $0.key == "first_quest" }?.unlocked ?? false)

        onlyQuest.status = .active
        onlyQuest.completedDate = nil
        ProgressionRebuildService.rebuild(context: context)

        let achievementsAfterUndo = try context.fetch(FetchDescriptor<Achievement>())
        XCTAssertFalse(achievementsAfterUndo.first { $0.key == "first_quest" }?.unlocked ?? true)
        XCTAssertEqual(character.level, 1)
    }
}
