import Foundation

enum RPGEquipmentSlot: String, Codable, CaseIterable, Sendable {
    case weapon
    case armor
    case accessory
}

enum RPGStat: String, Codable, CaseIterable, Sendable {
    case attack
    case defense
    case speed
    case endurance
    case magic
    case recovery

    var displayName: String { rawValue.capitalized }
}

/// A piece of gear the hero can equip. Gear is data-only for the MVP: it shapes
/// passive combat visuals/flavor, and the stat bonuses are ready for a future
/// combat simulator.
struct RPGEquipment: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let slot: RPGEquipmentSlot
    let iconAsset: String
    let requiredLevel: Int
    let classes: Set<RPGClass>
    let bonuses: [RPGStat: Int]
    let flavor: String

    func isUsable(by rpgClass: RPGClass, atLevel level: Int) -> Bool {
        classes.contains(rpgClass) && level >= requiredLevel
    }
}
