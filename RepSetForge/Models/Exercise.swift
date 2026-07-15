import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var canonicalNameKey: String = ""
    var muscleGroups: [MuscleGroup] = []
    var secondaryMuscles: [MuscleGroup] = []
    var equipment: Equipment = Equipment.other
    var isFavorite: Bool = false
    var isCustom: Bool = true
    /// Pinned note shown on the Exercise Focus screen (dev spec §3).
    var notes: String?
    var createdAt: Date = Date.now

    init(
        name: String,
        muscleGroups: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment = .other,
        isCustom: Bool = true,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.canonicalNameKey = Exercise.canonicalKey(for: name)
        self.muscleGroups = muscleGroups
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCustom = isCustom
        self.notes = notes
        self.createdAt = .now
    }

    /// Lowercased, punctuation-stripped name used for dedup matching (dev spec §2, `ExerciseDedupService`).
    static func canonicalKey(for name: String) -> String {
        name
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
