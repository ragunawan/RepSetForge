import Foundation

/// Canonical catalog of milestone bosses and the big quests that defeat them.
/// To add a boss: define its milestone quest, add the boss entry, and generate
/// its sprite in scripts/generate_pixel_assets.py.
enum RPGBossRegistry {

    static let milestoneQuests: [RPGMilestoneQuest] = [
        RPGMilestoneQuest(
            id: "milestone_first_5_workouts",
            title: "First Real Challenge",
            detail: "Complete 5 total quests.",
            requirement: .totalWorkouts(5)
        ),
        RPGMilestoneQuest(
            id: "milestone_7_day_streak",
            title: "Consistency Check",
            detail: "Complete quests on 7 consecutive days.",
            requirement: .workoutStreakDays(7)
        ),
        RPGMilestoneQuest(
            id: "milestone_endurance_trial",
            title: "Endurance Trial",
            detail: "Earn 7,500 total XP of training volume.",
            requirement: .totalXP(7_500)
        ),
        RPGMilestoneQuest(
            id: "milestone_discipline_trial",
            title: "Discipline Trial",
            detail: "Complete 40 total quests.",
            requirement: .totalWorkouts(40)
        ),
        RPGMilestoneQuest(
            id: "milestone_heroic_transformation",
            title: "Heroic Transformation",
            detail: "Earn 20,000 total XP of training volume.",
            requirement: .totalXP(20_000)
        ),
    ]

    static let all: [RPGBoss] = [
        RPGBoss(
            id: "iron_goblin_captain", name: "Iron Goblin Captain",
            requiredLevel: 10, milestoneQuestID: "milestone_first_5_workouts",
            spriteAsset: "rpg_boss_iron_goblin_captain",
            idleStyle: .shamble, attackStyle: .stomp,
            phaseText: "The Iron Goblin Captain blocks the road!",
            defeatText: "The captain's iron helm clatters to the ground.",
            difficulty: .challenger, backgroundAsset: "rpg_bg_boss"
        ),
        RPGBoss(
            id: "bone_colossus", name: "Bone Colossus",
            requiredLevel: 20, milestoneQuestID: "milestone_7_day_streak",
            spriteAsset: "rpg_boss_bone_colossus",
            idleStyle: .stomp, attackStyle: .stomp,
            phaseText: "The Bone Colossus tests your consistency!",
            defeatText: "The colossus crumbles, bone by bone.",
            difficulty: .veteran, backgroundAsset: "rpg_bg_boss"
        ),
        RPGBoss(
            id: "storm_wyvern", name: "Storm Wyvern",
            requiredLevel: 30, milestoneQuestID: "milestone_endurance_trial",
            spriteAsset: "rpg_boss_storm_wyvern",
            idleStyle: .hover, attackStyle: .flicker,
            phaseText: "The Storm Wyvern circles overhead, waiting you out!",
            defeatText: "The storm breaks. The wyvern flees the sky.",
            difficulty: .elite, backgroundAsset: "rpg_bg_boss"
        ),
        RPGBoss(
            id: "infernal_champion", name: "Infernal Champion",
            requiredLevel: 40, milestoneQuestID: "milestone_discipline_trial",
            spriteAsset: "rpg_boss_infernal_champion",
            idleStyle: .stomp, attackStyle: .stomp,
            phaseText: "The Infernal Champion demands discipline!",
            defeatText: "The champion kneels — the flames go quiet.",
            difficulty: .nightmare, backgroundAsset: "rpg_bg_boss"
        ),
        RPGBoss(
            id: "ancient_dragon", name: "Ancient Dragon",
            requiredLevel: 50, milestoneQuestID: "milestone_heroic_transformation",
            spriteAsset: "rpg_boss_ancient_dragon",
            idleStyle: .hover, attackStyle: .stomp,
            phaseText: "The Ancient Dragon awaits a true hero!",
            defeatText: "The dragon bows its head. You have transformed.",
            difficulty: .mythic, backgroundAsset: "rpg_bg_boss"
        ),
    ]

    private static let bossByID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static let questByID = Dictionary(uniqueKeysWithValues: milestoneQuests.map { ($0.id, $0) })

    static func boss(id: String) -> RPGBoss? { bossByID[id] }
    static func milestoneQuest(id: String) -> RPGMilestoneQuest? { questByID[id] }

    static func milestoneQuest(for boss: RPGBoss) -> RPGMilestoneQuest? {
        questByID[boss.milestoneQuestID]
    }
}
