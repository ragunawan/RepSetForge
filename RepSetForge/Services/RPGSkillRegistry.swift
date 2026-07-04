import Foundation

/// Canonical catalog of skills the hero can trigger during passive combat.
/// To add a skill, append an entry and generate its icon in
/// scripts/generate_pixel_assets.py.
enum RPGSkillRegistry {

    static let all: [RPGSkill] = [
        RPGSkill(
            id: "power_strike", name: "Power Strike",
            detail: "A heavy overhead blow that staggers the enemy.",
            requiredLevel: 2, classes: [.knight, .monk], cooldown: 8,
            iconAsset: "rpg_skill_power_strike", animation: .slash, effect: .physical,
            passiveWeight: 12, relatedMuscles: [.chest, .arms]
        ),
        RPGSkill(
            id: "quick_shot", name: "Quick Shot",
            detail: "Two arrows loosed faster than a blink.",
            requiredLevel: 2, classes: [.ranger, .rogue], cooldown: 6,
            iconAsset: "rpg_skill_quick_shot", animation: .shot, effect: .physical,
            passiveWeight: 14, relatedMuscles: [.arms, .legs]
        ),
        RPGSkill(
            id: "firebolt", name: "Firebolt",
            detail: "A searing bolt of elemental flame.",
            requiredLevel: 2, classes: [.mage], cooldown: 7,
            iconAsset: "rpg_skill_firebolt", animation: .burst, effect: .fire,
            passiveWeight: 14, relatedMuscles: [.shoulders, .arms]
        ),
        RPGSkill(
            id: "heal_pulse", name: "Heal Pulse",
            detail: "A restoring wave that steadies the hero.",
            requiredLevel: 4, classes: [.mage, .monk], cooldown: 14,
            iconAsset: "rpg_skill_heal_pulse", animation: .aura, effect: .holy,
            passiveWeight: 6, relatedMuscles: [.core, .back]
        ),
        RPGSkill(
            id: "shadow_dash", name: "Shadow Dash",
            detail: "Blink through the enemy, blades first.",
            requiredLevel: 3, classes: [.rogue], cooldown: 9,
            iconAsset: "rpg_skill_shadow_dash", animation: .dash, effect: .shadow,
            passiveWeight: 12, relatedMuscles: [.legs, .cardio]
        ),
        RPGSkill(
            id: "iron_guard", name: "Iron Guard",
            detail: "Plant your feet and shrug off the blow.",
            requiredLevel: 6, classes: [.knight, .monk], cooldown: 12,
            iconAsset: "rpg_skill_iron_guard", animation: .aura, effect: .guardEffect,
            passiveWeight: 7, relatedMuscles: [.chest, .core]
        ),
        RPGSkill(
            id: "endurance_aura", name: "Endurance Aura",
            detail: "Steady breathing turns fatigue into power.",
            requiredLevel: 8, classes: [.monk, .ranger], cooldown: 16,
            iconAsset: "rpg_skill_endurance_aura", animation: .aura, effect: .holy,
            passiveWeight: 6, relatedMuscles: [.legs, .cardio]
        ),
        RPGSkill(
            id: "boss_breaker", name: "Boss Breaker",
            detail: "A milestone-shattering strike. Only bosses warrant it.",
            requiredLevel: 10, classes: Set(RPGClass.allCases), cooldown: 20,
            iconAsset: "rpg_skill_boss_breaker", animation: .burst, effect: .physical,
            passiveWeight: 10, bossOnly: true, relatedMuscles: [.chest, .core]
        ),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func skill(id: String) -> RPGSkill? { byID[id] }

    static func usable(by rpgClass: RPGClass, atLevel level: Int, bossFight: Bool) -> [RPGSkill] {
        all.filter { $0.isUsable(by: rpgClass, atLevel: level, bossFight: bossFight) }
    }
}
