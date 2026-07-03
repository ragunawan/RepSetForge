import Foundation

/// Builds a fresh, editable Quest from a previously completed one so a
/// repeated workout doesn't require re-entering every exercise and set.
enum QuestDuplicationService {
    /// Creates a new active Quest dated today, cloning the source quest's
    /// exercises and each set's exact reps/weight (unlike QuestTemplateService,
    /// which only applies one default scheme across all sets). All cloned sets
    /// start uncompleted and the new quest carries no reward state.
    static func duplicate(_ quest: Quest) -> Quest {
        let copy = Quest(name: quest.name, status: .active)
        for exercise in quest.exercises {
            let exerciseCopy = Exercise(
                name: exercise.name,
                primaryMuscle: exercise.primaryMuscle,
                secondaryMuscles: exercise.secondaryMuscles,
                notes: exercise.notes
            )
            for set in exercise.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                exerciseCopy.sets.append(
                    ExerciseSet(setNumber: set.setNumber, reps: set.reps, weight: set.weight)
                )
            }
            copy.exercises.append(exerciseCopy)
        }
        return copy
    }
}
