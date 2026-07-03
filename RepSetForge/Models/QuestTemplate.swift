import Foundation
import SwiftData

/// A single skill's blueprint within a QuestTemplate — a self-contained
/// snapshot (not a reference to ExerciseTemplate) so deleting an exercise
/// template elsewhere never breaks a saved quest template.
struct QuestExerciseBlueprint: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var primaryMuscleRaw: String
    var secondaryMuscleRawValues: [String]
    var notes: String
    var defaultSetCount: Int
    var defaultReps: Int
    var defaultWeight: Double

    init(
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        notes: String = "",
        defaultSetCount: Int = 3,
        defaultReps: Int = 10,
        defaultWeight: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMuscleRawValues = secondaryMuscles.map(\.rawValue)
        self.notes = notes
        self.defaultSetCount = defaultSetCount
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMuscleRawValues.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMuscleRawValues = newValue.map(\.rawValue) }
    }
}

/// A saved, reusable workout plan — e.g. Push Day or Leg Day — as an ordered
/// list of skill blueprints. Starting a quest from a template pre-fills its
/// exercises and default set schemes without re-entering every skill.
@Model
final class QuestTemplate {
    var id: UUID
    var name: String
    var exerciseBlueprints: [QuestExerciseBlueprint]

    init(name: String, exerciseBlueprints: [QuestExerciseBlueprint] = []) {
        self.id = UUID()
        self.name = name
        self.exerciseBlueprints = exerciseBlueprints
    }
}
