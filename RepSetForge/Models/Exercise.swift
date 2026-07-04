import Foundation
import SwiftData

/// A "skill" performed within a Quest — a strength exercise targeting one primary
/// and optionally several secondary muscle groups.
@Model
final class Exercise {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var id: UUID = UUID()
    var name: String = ""
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    var secondaryMuscleRawValues: [String] = []
    var notes: String = ""
    var defaultRestSeconds: Int = 60
    var exerciseTypeRaw: String = ExerciseType.strength.rawValue
    /// Rate of Perceived Exertion for this exercise specifically, 1 (very easy) to 10 (max effort). Optional since not every exercise gets rated.
    var perceivedEffort: Int?

    // CloudKit requires to-many relationships to be Optional at the stored
    // property level — a default value alone (like every other attribute in
    // this file) isn't enough for relationships specifically. This private
    // optional backing + public non-optional computed accessor keeps every
    // other call site in the codebase working with a plain `[ExerciseSet]`,
    // unaware anything changed.
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    private var setsStorage: [ExerciseSet]?

    var sets: [ExerciseSet] {
        get { setsStorage ?? [] }
        set { setsStorage = newValue }
    }

    var quest: Quest?

    init(
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        notes: String = "",
        defaultRestSeconds: Int = 60,
        exerciseType: ExerciseType = .strength
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMuscleRawValues = secondaryMuscles.map(\.rawValue)
        self.notes = notes
        self.defaultRestSeconds = defaultRestSeconds
        self.exerciseTypeRaw = exerciseType.rawValue
        self.perceivedEffort = nil
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

    /// Sets marked complete, in logged order.
    var completedSets: [ExerciseSet] {
        sets.filter(\.completed).sorted { $0.setNumber < $1.setNumber }
    }
}
