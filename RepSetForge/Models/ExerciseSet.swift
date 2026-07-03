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

    var exercise: Exercise?

    init(setNumber: Int, reps: Int = 0, weight: Double = 0, completed: Bool = false) {
        self.id = UUID()
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.completed = completed
    }
}
