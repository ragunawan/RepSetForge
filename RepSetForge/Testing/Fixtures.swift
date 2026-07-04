import Foundation
import SwiftData

/// Shared, lightweight object builders for tests and `#Preview`s. Lives in
/// the app target (not the test target) specifically so both `#Preview`
/// blocks and `@testable import RepSetForge` test files can use the same
/// helpers — a second copy in the test target couldn't be seen by previews.
///
/// This consolidates the most commonly hand-duplicated pattern across the
/// test suite (a dozen-plus files each reimplement their own slightly
/// different `completedQuest(...)`/`makeCharacter(...)` helper) into one
/// place for new tests and previews to reach for. Existing test files keep
/// their own local helpers rather than being mass-migrated — many differ in
/// small, deliberate ways (volume-based vs. reps/weight-based, UTC calendars
/// for date-boundary tests, etc.) that aren't worth the risk of reconciling
/// wholesale into one shape.
enum Fixtures {
    /// An in-memory container over the full app schema — enough for any
    /// fixture below, and fast enough that there's rarely a reason to scope
    /// it down to a subset of models for a test or preview.
    static func makeContainer(models: [any PersistentModel.Type] = RepSetForgeSchemaV1.models) -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    static func makeCharacter(
        level: Int = 1,
        currentXP: Int = 0,
        totalXP: Int = 0,
        title: String = "Novice Adventurer",
        completedQuestCount: Int = 0,
        gold: Int = 0
    ) -> PlayerCharacter {
        PlayerCharacter(
            level: level,
            currentXP: currentXP,
            totalXP: totalXP,
            title: title,
            completedQuestCount: completedQuestCount,
            gold: gold
        )
    }

    /// One `MuscleProgress` row per `MuscleGroup`, all at level 1 — the same
    /// baseline `PersistenceController.seedCoreDataIfNeeded()` seeds for a
    /// real fresh install.
    static func makeMuscles() -> [MuscleProgress] {
        MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
    }

    static func makeExercise(
        name: String = "Bench Press",
        primary: MuscleGroup = .chest,
        secondary: [MuscleGroup] = [],
        sets: [(reps: Int, weight: Double, completed: Bool)] = [(8, 135, true)]
    ) -> Exercise {
        let exercise = Exercise(name: name, primaryMuscle: primary, secondaryMuscles: secondary)
        exercise.sets = sets.enumerated().map { index, set in
            ExerciseSet(setNumber: index + 1, reps: set.reps, weight: set.weight, completed: set.completed)
        }
        return exercise
    }

    static func makeQuest(
        name: String = "Push Day",
        status: QuestStatus = .planned,
        daysAgo: Int = 0,
        exercises: [Exercise] = []
    ) -> Quest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let quest = Quest(name: name, date: date, status: status)
        quest.exercises = exercises
        if status == .completed {
            quest.completedDate = date
        }
        return quest
    }

    /// The single most duplicated fixture across the test suite: a
    /// completed quest with one exercise and one completed set. Covers the
    /// common case; build a quest with `makeExercise`/`makeQuest` directly
    /// for anything needing more than one exercise or set.
    static func makeCompletedQuest(
        name: String = "Push Day",
        exerciseName: String = "Bench Press",
        primary: MuscleGroup = .chest,
        reps: Int = 8,
        weight: Double = 135,
        daysAgo: Int = 0
    ) -> Quest {
        let exercise = makeExercise(name: exerciseName, primary: primary, sets: [(reps, weight, true)])
        return makeQuest(name: name, status: .completed, daysAgo: daysAgo, exercises: [exercise])
    }

    @discardableResult
    static func seedAchievements(context: ModelContext) -> [Achievement] {
        let achievements = AchievementService.seedDefinitions()
        for achievement in achievements {
            context.insert(achievement)
        }
        return achievements
    }
}
