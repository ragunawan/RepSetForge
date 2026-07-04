import Foundation
import SwiftData

/// Singleton persisting the RPG layer's long-lived state: the hero's class and
/// any active/completed boss milestones. Seeded once at first launch alongside
/// PlayerCharacter so boss fights survive app relaunches.
@Model
final class RPGEncounterState {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var rpgClassRaw: String = RPGClass.knight.rawValue
    var activeBossID: String?
    var activeMilestoneQuestID: String?
    var completedBossIDs: [String] = []
    var completedMilestoneQuestIDs: [String] = []
    var lastDefeatedBossID: String?
    var lastBossDefeatDate: Date?

    init(
        rpgClass: RPGClass = .knight,
        activeBossID: String? = nil,
        activeMilestoneQuestID: String? = nil,
        completedBossIDs: [String] = [],
        completedMilestoneQuestIDs: [String] = [],
        lastDefeatedBossID: String? = nil,
        lastBossDefeatDate: Date? = nil
    ) {
        self.rpgClassRaw = rpgClass.rawValue
        self.activeBossID = activeBossID
        self.activeMilestoneQuestID = activeMilestoneQuestID
        self.completedBossIDs = completedBossIDs
        self.completedMilestoneQuestIDs = completedMilestoneQuestIDs
        self.lastDefeatedBossID = lastDefeatedBossID
        self.lastBossDefeatDate = lastBossDefeatDate
    }

    var rpgClass: RPGClass {
        get { RPGClass(rawValue: rpgClassRaw) ?? .knight }
        set { rpgClassRaw = newValue.rawValue }
    }
}
