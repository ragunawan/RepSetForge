import Foundation
import SwiftData

/// Singleton representing the player's overall RPG progression.
@Model
final class PlayerCharacter {
    var level: Int
    var currentXP: Int
    var totalXP: Int
    var title: String
    var completedQuestCount: Int
    var createdDate: Date
    /// Unit new sets are logged in by default. Changing this never rewrites
    /// already-logged sets, which each keep their own recorded unit.
    var preferredWeightUnitRaw: String = WeightUnit.pounds.rawValue

    init(
        level: Int = 1,
        currentXP: Int = 0,
        totalXP: Int = 0,
        title: String = "Novice Adventurer",
        completedQuestCount: Int = 0,
        createdDate: Date = .now,
        preferredWeightUnit: WeightUnit = .pounds
    ) {
        self.level = level
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.title = title
        self.completedQuestCount = completedQuestCount
        self.createdDate = createdDate
        self.preferredWeightUnitRaw = preferredWeightUnit.rawValue
    }

    /// XP required to advance from the current level to the next.
    var nextLevelXP: Int { level * 100 }

    var preferredWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: preferredWeightUnitRaw) ?? .pounds }
        set { preferredWeightUnitRaw = newValue.rawValue }
    }
}
