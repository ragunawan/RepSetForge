import Foundation

enum RPGEquipmentSlot: String, Codable, CaseIterable, Sendable {
    case weapon
    case armor
    case accessory

    var displayName: String { rawValue.capitalized }
}

/// Cosmetic tier derived from an item's level requirement, so the shop can
/// show a badge without needing a separately-authored field per item.
enum RPGItemRarity: Int, Comparable, Sendable {
    case common
    case uncommon
    case rare
    case epic

    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        }
    }

    static func < (lhs: RPGItemRarity, rhs: RPGItemRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
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
    /// Gold cost in the Equipment/Shop screen.
    let price: Int

    func isUsable(by rpgClass: RPGClass, atLevel level: Int) -> Bool {
        classes.contains(rpgClass) && level >= requiredLevel
    }

    /// Cosmetic tier derived from the level requirement — no separate
    /// per-item authoring needed.
    var rarity: RPGItemRarity {
        switch requiredLevel {
        case ..<2: return .common
        case 2..<10: return .uncommon
        case 10..<15: return .rare
        default: return .epic
        }
    }
}
