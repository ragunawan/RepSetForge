import Foundation
import SwiftData

/// Persisted, real-training-driven progression for a single `RPGSkill`
/// (matched by `skillID`). Seeded once per catalog entry so skills unlock
/// from accumulated skill XP instead of purely from character level.
@Model
final class SkillProgress {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var skillID: String = ""
    var currentXP: Int = 0
    var totalXP: Int = 0
    var unlocked: Bool = false
    var unlockedDate: Date?
    /// Whether this skill is the active loadout choice for its category.
    /// At most one skill per `RPGSkillCategory` should be equipped at a time.
    var equipped: Bool = false

    init(
        skillID: String,
        currentXP: Int = 0,
        totalXP: Int = 0,
        unlocked: Bool = false,
        unlockedDate: Date? = nil,
        equipped: Bool = false
    ) {
        self.skillID = skillID
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.unlocked = unlocked
        self.unlockedDate = unlockedDate
        self.equipped = equipped
    }
}
