import Foundation
import SwiftData

/// Persisted ownership of one `RPGEquipment` catalog entry (matched by
/// `equipmentID`). `RPGEquipment` itself stays static catalog data — this is
/// the per-player record of what's actually been acquired and what's
/// currently equipped, so gear is earned rather than always auto-available.
@Model
final class OwnedEquipment {
    var id: UUID
    /// Matches `RPGEquipment.id` in `RPGEquipmentRegistry`.
    var equipmentID: String
    var owned: Bool
    var equipped: Bool
    /// Where this item came from, e.g. "starter", "shop", "quest_drop".
    var purchaseSource: String
    var acquiredDate: Date

    init(
        equipmentID: String,
        owned: Bool = true,
        equipped: Bool = false,
        purchaseSource: String,
        acquiredDate: Date = .now
    ) {
        self.id = UUID()
        self.equipmentID = equipmentID
        self.owned = owned
        self.equipped = equipped
        self.purchaseSource = purchaseSource
        self.acquiredDate = acquiredDate
    }
}
