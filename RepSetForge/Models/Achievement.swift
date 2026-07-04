import Foundation
import SwiftData

/// A milestone the player can unlock. All definitions are seeded at first launch
/// with `unlocked = false`; AchievementService flips them on as conditions are met.
@Model
final class Achievement {
    // CloudKit doesn't support unique constraints (dropped `@Attribute(.unique)`
    // below) or non-optional/non-defaulted attributes — every SwiftData
    // attribute must be optional or have a default value. Uniqueness is
    // enforced at the application level instead: `seedCoreDataIfNeeded()`
    // only inserts a definition whose `key` isn't already present.
    /// Stable identifier matching an AchievementService.Definition.key.
    var key: String = ""
    var name: String = ""
    var detail: String = ""
    var iconName: String = ""
    var unlocked: Bool = false
    var unlockedDate: Date?

    init(
        key: String,
        name: String,
        detail: String,
        iconName: String,
        unlocked: Bool = false,
        unlockedDate: Date? = nil
    ) {
        self.key = key
        self.name = name
        self.detail = detail
        self.iconName = iconName
        self.unlocked = unlocked
        self.unlockedDate = unlockedDate
    }
}
