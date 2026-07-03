import Foundation
import SwiftData

/// A saved, reusable definition of a skill — name, muscle groups, notes, and
/// a default set scheme — so common exercises don't need retyping per Quest.
@Model
final class ExerciseTemplate {
    var id: UUID
    var name: String
    var primaryMuscleRaw: String
    var secondaryMuscleRawValues: [String]
    var notes: String
    var defaultSetCount: Int
    var defaultReps: Int
    var defaultWeight: Double
    var defaultRestSeconds: Int = 60
    var exerciseTypeRaw: String = ExerciseType.strength.rawValue
    var defaultDistanceMiles: Double = 0
    var defaultDurationSeconds: Int = 0

    init(
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        notes: String = "",
        defaultSetCount: Int = 3,
        defaultReps: Int = 10,
        defaultWeight: Double = 0,
        defaultRestSeconds: Int = 60,
        exerciseType: ExerciseType = .strength,
        defaultDistanceMiles: Double = 0,
        defaultDurationSeconds: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMuscleRawValues = secondaryMuscles.map(\.rawValue)
        self.notes = notes
        self.defaultSetCount = defaultSetCount
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
        self.defaultRestSeconds = defaultRestSeconds
        self.exerciseTypeRaw = exerciseType.rawValue
        self.defaultDistanceMiles = defaultDistanceMiles
        self.defaultDurationSeconds = defaultDurationSeconds
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .strength }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMuscleRawValues.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMuscleRawValues = newValue.map(\.rawValue) }
    }
}
