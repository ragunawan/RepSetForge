import Foundation
import SwiftData

/// Deterministic, occasional equipment drops from completed-quest and
/// personal-record milestones. Never random per-tap: the item granted at a
/// given milestone count is a pure function of that count and what's already
/// owned, so replaying history (via `ProgressionRebuildService`) always
/// reproduces the same drops.
enum EquipmentDropService {
    static let questMilestoneInterval = 3
    static let prMilestoneInterval = 3

    static let questDropSource = "quest_drop"
    static let prDropSource = "pr_drop"

    struct DropResult {
        let equipmentID: String
        let name: String
    }

    /// Grants a drop when `completedQuestCount` is a positive multiple of
    /// `questMilestoneInterval` (e.g. the 3rd, 6th, 9th completed quest).
    @discardableResult
    static func checkQuestMilestone(
        completedQuestCount: Int,
        rpgClass: RPGClass,
        context: ModelContext,
        acquiredDate: Date = .now
    ) -> DropResult? {
        guard completedQuestCount > 0, completedQuestCount.isMultiple(of: questMilestoneInterval) else { return nil }
        return grantDeterministicDrop(
            seed: "quest-\(completedQuestCount)",
            rpgClass: rpgClass,
            source: questDropSource,
            context: context,
            acquiredDate: acquiredDate
        )
    }

    /// Grants a drop when the cumulative personal-record count is a positive
    /// multiple of `prMilestoneInterval`.
    @discardableResult
    static func checkPRMilestone(
        totalPRCount: Int,
        rpgClass: RPGClass,
        context: ModelContext,
        acquiredDate: Date = .now
    ) -> DropResult? {
        guard totalPRCount > 0, totalPRCount.isMultiple(of: prMilestoneInterval) else { return nil }
        return grantDeterministicDrop(
            seed: "pr-\(totalPRCount)",
            rpgClass: rpgClass,
            source: prDropSource,
            context: context,
            acquiredDate: acquiredDate
        )
    }

    /// Picks a not-yet-owned, class-usable item deterministically from
    /// `seed` (a pure hash, not real randomness) and grants it. No-op if
    /// nothing is left to drop for this class.
    private static func grantDeterministicDrop(
        seed: String,
        rpgClass: RPGClass,
        source: String,
        context: ModelContext,
        acquiredDate: Date
    ) -> DropResult? {
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        let ownedIDs = Set(owned.filter(\.owned).map(\.equipmentID))
        let candidates = RPGEquipmentRegistry.all
            .filter { $0.classes.contains(rpgClass) && !ownedIDs.contains($0.id) }
            .sorted { $0.id < $1.id }

        guard !candidates.isEmpty else { return nil }
        let index = stableHash(seed) % candidates.count
        let picked = candidates[index]

        context.insert(OwnedEquipment(equipmentID: picked.id, owned: true, equipped: false, purchaseSource: source, acquiredDate: acquiredDate))
        return DropResult(equipmentID: picked.id, name: picked.name)
    }

    /// FNV-1a hash. Deterministic across app launches, unlike `String.hashValue`
    /// (which is randomized per process) — required so a rebuild in a later
    /// session picks the exact same drop as the original grant did.
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % UInt64(Int.max))
    }
}
