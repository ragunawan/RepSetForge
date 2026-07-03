import Foundation

/// Builds Exercise/ExerciseTemplate graphs from each other so the "load
/// template" and "save as template" flows share one place for the mapping.
enum ExerciseTemplateService {
    /// Creates a new Exercise pre-filled with the template's muscle groups,
    /// notes, and a run of unfilled sets matching its default set scheme.
    static func makeExercise(from template: ExerciseTemplate) -> Exercise {
        let exercise = Exercise(
            name: template.name,
            primaryMuscle: template.primaryMuscle,
            secondaryMuscles: template.secondaryMuscles,
            notes: template.notes,
            defaultRestSeconds: template.defaultRestSeconds,
            exerciseType: template.exerciseType
        )
        for index in 0..<max(0, template.defaultSetCount) {
            exercise.sets.append(
                ExerciseSet(
                    setNumber: index + 1,
                    reps: template.defaultReps,
                    weight: template.defaultWeight,
                    distanceMiles: template.defaultDistanceMiles,
                    durationSeconds: template.defaultDurationSeconds
                )
            )
        }
        return exercise
    }

    /// Saves the given skill definition as a reusable template.
    static func makeTemplate(
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup],
        notes: String,
        defaultSetCount: Int,
        defaultReps: Int,
        defaultWeight: Double,
        defaultRestSeconds: Int = 60,
        exerciseType: ExerciseType = .strength,
        defaultDistanceMiles: Double = 0,
        defaultDurationSeconds: Int = 0
    ) -> ExerciseTemplate {
        ExerciseTemplate(
            name: name,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            notes: notes,
            defaultSetCount: defaultSetCount,
            defaultReps: defaultReps,
            defaultWeight: defaultWeight,
            defaultRestSeconds: defaultRestSeconds,
            exerciseType: exerciseType,
            defaultDistanceMiles: defaultDistanceMiles,
            defaultDurationSeconds: defaultDurationSeconds
        )
    }
}
