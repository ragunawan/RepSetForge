import Foundation
import SwiftData

/// Manages persisted equipment ownership: seeding starter gear, resolving the
/// currently-equipped loadout, and swapping what's equipped per slot.
/// `RPGEquipmentRegistry` stays the static catalog; this is the per-player
/// state layered on top of it.
enum RPGEquipmentService {
    /// Grants the class's starter weapon plus the universal starter armor,
    /// owned and equipped. No-ops if the player already owns anything, so
    /// it's safe to call once after onboarding's class selection.
    @discardableResult
    static func seedStarterGear(for rpgClass: RPGClass, context: ModelContext) -> [OwnedEquipment] {
        let existing = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        guard existing.isEmpty else { return existing }

        let starterIDs = RPGEquipmentRegistry.all
            .filter { $0.requiredLevel == 1 && $0.isUsable(by: rpgClass, atLevel: 1) }
            .map(\.id)

        var seeded: [OwnedEquipment] = []
        for equipmentID in starterIDs {
            let owned = OwnedEquipment(equipmentID: equipmentID, owned: true, equipped: true, purchaseSource: "starter")
            context.insert(owned)
            seeded.append(owned)
        }
        return seeded
    }

    /// All catalog items the player currently owns.
    static func ownedEquipment(context: ModelContext) -> [RPGEquipment] {
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        return owned.filter(\.owned).compactMap { RPGEquipmentRegistry.equipment(id: $0.equipmentID) }
    }

    /// The currently-equipped item per slot, resolved from persisted
    /// ownership. Empty for any slot with nothing equipped.
    static func equippedLoadout(context: ModelContext) -> [RPGEquipmentSlot: RPGEquipment] {
        equippedLoadout(from: (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? [])
    }

    static func equippedLoadout(from owned: [OwnedEquipment]) -> [RPGEquipmentSlot: RPGEquipment] {
        var result: [RPGEquipmentSlot: RPGEquipment] = [:]
        for record in owned where record.owned && record.equipped {
            guard let equipment = RPGEquipmentRegistry.equipment(id: record.equipmentID) else { continue }
            result[equipment.slot] = equipment
        }
        return result
    }

    /// Equips the given owned item, un-equipping whatever else was equipped
    /// in the same slot. No-ops if the item isn't owned.
    static func equip(_ equipmentID: String, context: ModelContext) {
        guard let target = RPGEquipmentRegistry.equipment(id: equipmentID) else { return }
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        guard let targetRecord = owned.first(where: { $0.equipmentID == equipmentID && $0.owned }) else { return }

        for record in owned where record.equipped && record.equipmentID != equipmentID {
            if RPGEquipmentRegistry.equipment(id: record.equipmentID)?.slot == target.slot {
                record.equipped = false
            }
        }
        targetRecord.equipped = true
    }
}
