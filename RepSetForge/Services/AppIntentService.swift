import Foundation
import SwiftData

/// Pure logic behind the Shortcuts/Siri App Intents (see AppIntents.swift for
/// the thin `AppIntent` wrappers) — kept separate and `ModelContext`-parameterized
/// so it's directly unit-testable, matching every other service in this codebase.
enum AppIntentService {
    struct LogSetResult {
        let questName: String
        let exerciseName: String
    }

    enum LogSetError: Error, LocalizedError {
        case noActiveQuest

        var errorDescription: String? {
            switch self {
            case .noActiveQuest: return "You don't have an active quest to log a set to. Start one first."
            }
        }
    }

    @discardableResult
    static func startQuest(context: ModelContext) -> Quest {
        let quest = Quest(name: "New Quest", status: .active)
        context.insert(quest)
        try? context.save()
        return quest
    }

    /// Logs a completed set to the current active (or planned) quest's
    /// matching exercise, creating the exercise if it doesn't exist yet in
    /// that quest. A new exercise reuses the primary/secondary muscles and
    /// type from the most recently logged exercise of the same name
    /// anywhere in history, if one exists, so a Shortcut doesn't need to ask
    /// "which muscle group?" for an exercise the player has already logged.
    static func logSet(
        exerciseName: String,
        reps: Int,
        weight: Double,
        weightUnit: WeightUnit,
        context: ModelContext
    ) throws -> LogSetResult {
        let allQuests = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        guard let quest = allQuests.first(where: { $0.status != .completed }) else {
            throw LogSetError.noActiveQuest
        }

        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = quest.exercises.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            let nextNumber = (existing.sets.map(\.setNumber).max() ?? 0) + 1
            existing.sets.append(ExerciseSet(setNumber: nextNumber, reps: reps, weight: weight, completed: true, weightUnit: weightUnit))
        } else {
            let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let historical = allExercises.first { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
            let exercise = Exercise(
                name: trimmedName,
                primaryMuscle: historical?.primaryMuscle ?? .chest,
                secondaryMuscles: historical?.secondaryMuscles ?? [],
                exerciseType: historical?.exerciseType ?? .strength
            )
            exercise.sets.append(ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true, weightUnit: weightUnit))
            quest.exercises.append(exercise)
        }

        try? context.save()
        return LogSetResult(questName: quest.name, exerciseName: trimmedName)
    }

    static func currentLevelSummary(context: ModelContext) -> (level: Int, title: String) {
        let character = (try? context.fetch(FetchDescriptor<PlayerCharacter>()))?.first
        return (character?.level ?? 1, character?.title ?? "Novice Adventurer")
    }
}
