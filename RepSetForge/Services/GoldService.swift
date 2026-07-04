import Foundation

/// Deterministic gold rewards, so completed-quest history can always be
/// replayed to the same total (no per-tap randomness to reproduce).
enum GoldService {
    static let goldPerCompletedSet = 1
    static let goldPerPersonalRecord = 25

    /// A small trickle of gold per completed set, so a quest in progress
    /// already feels rewarding before it's finished.
    static func setGold(completedSetCount: Int) -> Int {
        completedSetCount * goldPerCompletedSet
    }

    /// The larger, quest-level reward: scales with the quest's total XP.
    static func questGold(totalXP: Int) -> Int {
        totalXP / 10
    }

    /// Bonus gold for each personal record newly set or broken this quest.
    static func personalRecordGold(newRecordCount: Int) -> Int {
        newRecordCount * goldPerPersonalRecord
    }

    /// Total gold for completing a quest with the given completed set count,
    /// total XP, and number of newly set/broken personal records.
    static func totalGold(completedSetCount: Int, questXP: Int, newRecordCount: Int) -> Int {
        setGold(completedSetCount: completedSetCount)
            + questGold(totalXP: questXP)
            + personalRecordGold(newRecordCount: newRecordCount)
    }
}
