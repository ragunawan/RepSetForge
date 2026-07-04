import Foundation

/// Builds Quest/QuestTemplate graphs from each other so the "start from
/// template" and "save as template" flows share one place for the mapping.
enum QuestTemplateService {
    /// Creates a new active Quest named after the template, with one Exercise
    /// per blueprint, each pre-filled with unfilled sets matching its default
    /// set scheme. `unit` tags the new sets' weight (templates store only
    /// numeric defaults) — typically the character's preferred unit.
    static func makeQuest(from template: QuestTemplate, unit: WeightUnit = .pounds) -> Quest {
        makeQuest(name: template.name, exerciseBlueprints: template.exerciseBlueprints, unit: unit)
    }

    /// Shared builder behind `makeQuest(from:unit:)`, also used by
    /// `SuggestedQuestService` for suggestions that aren't backed by a saved
    /// `QuestTemplate`.
    static func makeQuest(name: String, exerciseBlueprints: [QuestExerciseBlueprint], unit: WeightUnit = .pounds) -> Quest {
        let quest = Quest(name: name, status: .active)
        for blueprint in exerciseBlueprints {
            let exercise = Exercise(
                name: blueprint.name,
                primaryMuscle: blueprint.primaryMuscle,
                secondaryMuscles: blueprint.secondaryMuscles,
                notes: blueprint.notes,
                defaultRestSeconds: blueprint.defaultRestSeconds,
                exerciseType: blueprint.exerciseType
            )
            for index in 0..<max(0, blueprint.defaultSetCount) {
                exercise.sets.append(
                    ExerciseSet(
                        setNumber: index + 1,
                        reps: blueprint.defaultReps,
                        weight: blueprint.defaultWeight,
                        distanceMiles: blueprint.defaultDistanceMiles,
                        durationSeconds: blueprint.defaultDurationSeconds,
                        weightUnit: unit
                    )
                )
            }
            quest.exercises.append(exercise)
        }
        return quest
    }

    /// Saves the given quest's exercises as a reusable template. Each
    /// blueprint's default set scheme is snapshotted from the exercise's
    /// current sets (set count, and the first set's reps/weight), falling
    /// back to the Exercise's own defaults when it has no sets yet.
    static func makeTemplate(name: String, exercises: [Exercise]) -> QuestTemplate {
        QuestTemplate(name: name, exerciseBlueprints: exercises.map(blueprint(from:)))
    }

    /// Snapshots one Exercise's current sets into a self-contained blueprint —
    /// shared by `makeTemplate` and `SuggestedQuestService`, which snapshots
    /// exercises from a completed quest rather than from a saved template.
    static func blueprint(from exercise: Exercise) -> QuestExerciseBlueprint {
        let firstSet = exercise.sets.sorted { $0.setNumber < $1.setNumber }.first
        return QuestExerciseBlueprint(
            name: exercise.name,
            primaryMuscle: exercise.primaryMuscle,
            secondaryMuscles: exercise.secondaryMuscles,
            notes: exercise.notes,
            defaultSetCount: exercise.sets.count,
            defaultReps: firstSet?.reps ?? 10,
            defaultWeight: firstSet?.weight ?? 0,
            defaultRestSeconds: exercise.defaultRestSeconds,
            exerciseType: exercise.exerciseType,
            defaultDistanceMiles: firstSet?.distanceMiles ?? 0,
            defaultDurationSeconds: firstSet?.durationSeconds ?? 0
        )
    }
}
