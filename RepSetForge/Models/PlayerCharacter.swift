import Foundation
import SwiftData

/// Singleton representing the player's overall RPG progression.
@Model
final class PlayerCharacter {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var level: Int = 1
    var currentXP: Int = 0
    var totalXP: Int = 0
    var title: String = "Novice Adventurer"
    var completedQuestCount: Int = 0
    var createdDate: Date = Date.now
    /// Unit new sets are logged in by default. Changing this never rewrites
    /// already-logged sets, which each keep their own recorded unit.
    var preferredWeightUnitRaw: String = WeightUnit.pounds.rawValue
    /// Flips to true once the player finishes the first-run onboarding flow,
    /// so it's shown exactly once.
    var hasCompletedOnboarding: Bool = false
    /// Currency earned from completed sets, quests, and personal records.
    /// Spendable once the Equipment/Shop screen exists.
    var gold: Int = 0
    /// Cumulative count of personal-record events (new or re-broken), used to
    /// gate PR equipment-drop milestones. Not the same as the number of
    /// distinct `PersonalRecord` rows, since re-breaking an existing record
    /// counts again here but doesn't add a new row.
    var totalPRCount: Int = 0

    init(
        level: Int = 1,
        currentXP: Int = 0,
        totalXP: Int = 0,
        title: String = "Novice Adventurer",
        completedQuestCount: Int = 0,
        createdDate: Date = .now,
        preferredWeightUnit: WeightUnit = .pounds,
        hasCompletedOnboarding: Bool = false,
        gold: Int = 0,
        totalPRCount: Int = 0
    ) {
        self.level = level
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.title = title
        self.completedQuestCount = completedQuestCount
        self.createdDate = createdDate
        self.preferredWeightUnitRaw = preferredWeightUnit.rawValue
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.gold = gold
        self.totalPRCount = totalPRCount
    }

    /// XP required to advance from the current level to the next.
    var nextLevelXP: Int { level * 100 }

    var preferredWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: preferredWeightUnitRaw) ?? .pounds }
        set { preferredWeightUnitRaw = newValue.rawValue }
    }
}
