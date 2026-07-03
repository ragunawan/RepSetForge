import Foundation
import SwiftData

/// A single logged set (reps × weight) within an Exercise.
@Model
final class ExerciseSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var completed: Bool
    /// Distance in miles, for `.distance`/`.cardio` exercise types.
    var distanceMiles: Double = 0
    /// Duration in seconds, for `.duration`/`.cardio` exercise types.
    var durationSeconds: Int = 0
    /// Unit `weight` was recorded in. Defaults to pounds so sets logged
    /// before this field existed keep displaying correctly.
    var weightUnitRaw: String = WeightUnit.pounds.rawValue

    var exercise: Exercise?

    init(
        setNumber: Int,
        reps: Int = 0,
        weight: Double = 0,
        completed: Bool = false,
        distanceMiles: Double = 0,
        durationSeconds: Int = 0,
        weightUnit: WeightUnit = .pounds
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.distanceMiles = distanceMiles
        self.durationSeconds = durationSeconds
        self.weightUnitRaw = weightUnit.rawValue
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .pounds }
        set { weightUnitRaw = newValue.rawValue }
    }
}
