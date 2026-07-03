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

    init(
        level: Int = 1,
        currentXP: Int = 0,
        totalXP: Int = 0,
        title: String = "Novice Adventurer",
        completedQuestCount: Int = 0,
        createdDate: Date = .now
    ) {
        self.level = level
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.title = title
        self.completedQuestCount = completedQuestCount
        self.createdDate = createdDate
    }

    /// XP required to advance from the current level to the next.
    var nextLevelXP: Int { level * 100 }
}
