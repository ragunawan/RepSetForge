import Foundation

/// Boss lifecycle rules: when a milestone boss awakens, when it counts as
/// defeated, and how completion is recorded so it never immediately reappears.
/// Operates on the persisted RPGEncounterState plus a progression snapshot,
/// mirroring how ProgressionService mutates PlayerCharacter.
enum BossMilestoneService {

    /// The boss currently locking the scene, if any.
    static func activeBoss(state: RPGEncounterState) -> RPGBoss? {
        state.activeBossID.flatMap(RPGBossRegistry.boss(id:))
    }

    /// The lowest-level boss the player has reached but not yet defeated.
    /// Lowest first so a player who leveled quickly still faces bosses in order.
    static func eligibleBoss(snapshot: RPGProgressionSnapshot, state: RPGEncounterState) -> RPGBoss? {
        guard state.activeBossID == nil else { return nil }
        let completed = Set(state.completedBossIDs)
        return RPGBossRegistry.all
            .filter { snapshot.currentLevel >= $0.requiredLevel && !completed.contains($0.id) }
            .min { $0.requiredLevel < $1.requiredLevel }
    }

    /// Awakens the next eligible boss, persisting it as the active encounter.
    @discardableResult
    static func activateBossIfNeeded(state: RPGEncounterState, snapshot: RPGProgressionSnapshot) -> RPGBoss? {
        guard let boss = eligibleBoss(snapshot: snapshot, state: state) else { return nil }
        state.activeBossID = boss.id
        state.activeMilestoneQuestID = boss.milestoneQuestID
        return boss
    }

    /// True when the active boss's milestone quest is satisfied by real progress.
    static func isActiveBossDefeated(state: RPGEncounterState, snapshot: RPGProgressionSnapshot) -> Bool {
        guard let boss = activeBoss(state: state),
              let quest = RPGBossRegistry.milestoneQuest(for: boss) else { return false }
        return quest.isSatisfied(by: snapshot)
    }

    /// Records the defeat: boss and quest move to the completed lists so the
    /// boss cannot reactivate, and normal spawning resumes.
    static func completeActiveBoss(state: RPGEncounterState) {
        guard let boss = activeBoss(state: state) else { return }
        if !state.completedBossIDs.contains(boss.id) {
            state.completedBossIDs.append(boss.id)
        }
        if !state.completedMilestoneQuestIDs.contains(boss.milestoneQuestID) {
            state.completedMilestoneQuestIDs.append(boss.milestoneQuestID)
        }
        state.lastDefeatedBossID = boss.id
        state.lastBossDefeatDate = .now
        state.activeBossID = nil
        state.activeMilestoneQuestID = nil
    }
}
