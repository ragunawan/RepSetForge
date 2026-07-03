import Foundation

/// An ability the hero triggers automatically during passive combat.
struct RPGSkill: Identifiable, Equatable, Sendable {
    enum AnimationType: String, Sendable {
        case slash
        case shot
        case burst
        case aura
        case dash
    }

    enum EffectType: String, Sendable {
        case physical
        case fire
        case holy
        case shadow
        case guardEffect
    }

    let id: String
    let name: String
    let detail: String
    let requiredLevel: Int
    let classes: Set<RPGClass>
    /// Seconds before the skill can trigger again in the passive loop.
    let cooldown: TimeInterval
    let iconAsset: String
    let animation: AnimationType
    let effect: EffectType
    /// Relative likelihood of this skill being chosen when several are off cooldown.
    let passiveWeight: Int
    /// Boss-only skills are excluded from ordinary encounters.
    let bossOnly: Bool

    init(
        id: String,
        name: String,
        detail: String,
        requiredLevel: Int,
        classes: Set<RPGClass>,
        cooldown: TimeInterval,
        iconAsset: String,
        animation: AnimationType,
        effect: EffectType,
        passiveWeight: Int = 10,
        bossOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.requiredLevel = requiredLevel
        self.classes = classes
        self.cooldown = cooldown
        self.iconAsset = iconAsset
        self.animation = animation
        self.effect = effect
        self.passiveWeight = passiveWeight
        self.bossOnly = bossOnly
    }

    func isUsable(by rpgClass: RPGClass, atLevel level: Int, bossFight: Bool) -> Bool {
        classes.contains(rpgClass) && level >= requiredLevel && (!bossOnly || bossFight)
    }
}
