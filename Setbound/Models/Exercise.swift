import Foundation
import SwiftData

/// A "skill" performed within a Quest — a strength exercise targeting one primary
/// and optionally several secondary muscle groups.
@Model
final class Exercise {
    var id: UUID
    var name: String
    var primaryMuscleRaw: String
    var secondaryMuscleRawValues: [String]
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet] = []

    var quest: Quest?

    init(
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMuscleRawValues = secondaryMuscles.map(\.rawValue)
        self.notes = notes
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .chest }
        set { primaryMuscleRaw = newValue.rawValue }
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
