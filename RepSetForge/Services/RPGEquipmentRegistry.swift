import Foundation

/// Canonical catalog of equipment. Gear is auto-equipped for now: the hero
/// wears the best item their class and level allow. To add gear, append an
/// entry and generate its icon in scripts/generate_pixel_assets.py.
enum RPGEquipmentRegistry {

    static let all: [RPGEquipment] = [
        // Weapons
        RPGEquipment(
            id: "training_sword", name: "Training Sword", slot: .weapon,
            iconAsset: "rpg_equip_training_sword", requiredLevel: 1,
            classes: [.knight],
            bonuses: [.attack: 2],
            flavor: "Every legend starts with a dull edge.",
            price: 50
        ),
        RPGEquipment(
            id: "iron_dumbbell_axe", name: "Iron Dumbbell Axe", slot: .weapon,
            iconAsset: "rpg_equip_iron_dumbbell_axe", requiredLevel: 8,
            classes: [.knight, .monk],
            bonuses: [.attack: 5, .endurance: 2],
            flavor: "Forged from gym plates nobody re-racked.",
            price: 220
        ),
        RPGEquipment(
            id: "runners_bow", name: "Runner's Bow", slot: .weapon,
            iconAsset: "rpg_equip_runners_bow", requiredLevel: 1,
            classes: [.ranger],
            bonuses: [.attack: 2, .speed: 3],
            flavor: "Strung with a retired jump rope.",
            price: 50
        ),
        RPGEquipment(
            id: "focus_staff", name: "Focus Staff", slot: .weapon,
            iconAsset: "rpg_equip_focus_staff", requiredLevel: 1,
            classes: [.mage],
            bonuses: [.magic: 4],
            flavor: "Hums faintly during perfect form.",
            price: 50
        ),
        RPGEquipment(
            id: "shadow_daggers", name: "Shadow Daggers", slot: .weapon,
            iconAsset: "rpg_equip_shadow_daggers", requiredLevel: 1,
            classes: [.rogue],
            bonuses: [.attack: 3, .speed: 2],
            flavor: "Twin blades quick as a superset.",
            price: 50
        ),

        // Armor
        RPGEquipment(
            id: "beginner_armor", name: "Beginner Armor", slot: .armor,
            iconAsset: "rpg_equip_beginner_armor", requiredLevel: 1,
            classes: Set(RPGClass.allCases),
            bonuses: [.defense: 2],
            flavor: "Slightly used. Fits like day one.",
            price: 40
        ),
        RPGEquipment(
            id: "weighted_vest", name: "Weighted Vest", slot: .armor,
            iconAsset: "rpg_equip_weighted_vest", requiredLevel: 10,
            classes: [.ranger, .monk, .rogue],
            bonuses: [.defense: 3, .endurance: 4],
            flavor: "Heavier than it looks. That's the point.",
            price: 260
        ),
        RPGEquipment(
            id: "heroic_chestplate", name: "Heroic Chestplate", slot: .armor,
            iconAsset: "rpg_equip_heroic_chestplate", requiredLevel: 15,
            classes: [.knight, .monk],
            bonuses: [.defense: 6, .endurance: 2],
            flavor: "Polished by a thousand completed quests.",
            price: 400
        ),
        RPGEquipment(
            id: "mystic_robe", name: "Mystic Robe", slot: .armor,
            iconAsset: "rpg_equip_mystic_robe", requiredLevel: 12,
            classes: [.mage],
            bonuses: [.magic: 5, .recovery: 3],
            flavor: "Woven from rest-day serenity.",
            price: 320
        ),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func equipment(id: String) -> RPGEquipment? { byID[id] }

    static func usable(by rpgClass: RPGClass, atLevel level: Int, slot: RPGEquipmentSlot) -> [RPGEquipment] {
        all.filter { $0.slot == slot && $0.isUsable(by: rpgClass, atLevel: level) }
    }

    /// The auto-equipped loadout: highest-requirement usable item per slot.
    static func loadout(for rpgClass: RPGClass, atLevel level: Int) -> [RPGEquipmentSlot: RPGEquipment] {
        var result: [RPGEquipmentSlot: RPGEquipment] = [:]
        for slot in RPGEquipmentSlot.allCases {
            result[slot] = usable(by: rpgClass, atLevel: level, slot: slot)
                .max { $0.requiredLevel < $1.requiredLevel }
        }
        return result
    }
}
