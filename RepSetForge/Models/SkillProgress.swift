import Foundation
import SwiftData

/// Persisted, real-training-driven progression for a single `RPGSkill`
/// (matched by `skillID`). Seeded once per catalog entry so skills unlock
/// from accumulated skill XP instead of purely from character level.
@Model
final class SkillProgress {
    var skillID: String
    var currentXP: Int
    var totalXP: Int
    var unlocked: Bool
    var unlockedDate: Date?

    init(
        skillID: String,
        currentXP: Int = 0,
        totalXP: Int = 0,
        unlocked: Bool = false,
        unlockedDate: Date? = nil
    ) {
        self.skillID = skillID
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.unlocked = unlocked
        self.unlockedDate = unlockedDate
    }
}
