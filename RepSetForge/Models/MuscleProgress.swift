import Foundation
import SwiftData

/// Independent level/XP track for a single muscle group. One instance per MuscleGroup,
/// seeded at first launch.
@Model
final class MuscleProgress {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var level: Int = 1
    var currentXP: Int = 0
    var totalXP: Int = 0

    init(muscleGroup: MuscleGroup, level: Int = 1, currentXP: Int = 0, totalXP: Int = 0) {
        self.muscleGroupRaw = muscleGroup.rawValue
        self.level = level
        self.currentXP = currentXP
        self.totalXP = totalXP
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    /// XP required to advance from the current level to the next.
    var nextLevelXP: Int { level * 100 }
}
