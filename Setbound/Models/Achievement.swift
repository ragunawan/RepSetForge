import Foundation
import SwiftData

/// A milestone the player can unlock. All definitions are seeded at first launch
/// with `unlocked = false`; AchievementService flips them on as conditions are met.
@Model
final class Achievement {
    /// Stable identifier matching an AchievementService.Definition.key.
    @Attribute(.unique) var key: String
    var name: String
    var detail: String
    var iconName: String
    var unlocked: Bool
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
