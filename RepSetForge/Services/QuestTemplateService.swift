import Foundation

/// Builds Quest/QuestTemplate graphs from each other so the "start from
/// template" and "save as template" flows share one place for the mapping.
enum QuestTemplateService {
    /// Creates a new active Quest named after the template, with one Exercise
    /// per blueprint, each pre-filled with unfilled sets matching its default
    /// set scheme.
    static func makeQuest(from template: QuestTemplate) -> Quest {
        let quest = Quest(name: template.name, status: .active)
        for blueprint in template.exerciseBlueprints {
            let exercise = Exercise(
                name: blueprint.name,
                primaryMuscle: blueprint.primaryMuscle,
                secondaryMuscles: blueprint.secondaryMuscles,
                notes: blueprint.notes,
                defaultRestSeconds: blueprint.defaultRestSeconds
            )
            for index in 0..<max(0, blueprint.defaultSetCount) {
                exercise.sets.append(
                    ExerciseSet(setNumber: index + 1, reps: blueprint.defaultReps, weight: blueprint.defaultWeight)
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
        let blueprints = exercises.map { exercise -> QuestExerciseBlueprint in
            let firstSet = exercise.sets.sorted { $0.setNumber < $1.setNumber }.first
            return QuestExerciseBlueprint(
                name: exercise.name,
                primaryMuscle: exercise.primaryMuscle,
                secondaryMuscles: exercise.secondaryMuscles,
                notes: exercise.notes,
                defaultSetCount: exercise.sets.count,
                defaultReps: firstSet?.reps ?? 10,
                defaultWeight: firstSet?.weight ?? 0,
                defaultRestSeconds: exercise.defaultRestSeconds
            )
        }
        return QuestTemplate(name: name, exerciseBlueprints: blueprints)
    }
}
