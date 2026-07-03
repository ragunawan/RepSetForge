import Foundation

/// A big milestone quest tied to real training progress. Bosses are defeated
/// only when their milestone quest's requirement is satisfied.
struct RPGMilestoneQuest: Identifiable, Equatable, Sendable {
    enum Requirement: Equatable, Sendable {
        case totalWorkouts(Int)
        case workoutStreakDays(Int)
        case totalXP(Int)
    }

    let id: String
    let title: String
    let detail: String
    let requirement: Requirement

    func isSatisfied(by snapshot: RPGProgressionSnapshot) -> Bool {
        switch requirement {
        case .totalWorkouts(let count):
            return snapshot.completedWorkoutCount >= count
        case .workoutStreakDays(let days):
            return snapshot.currentWorkoutStreak >= days
        case .totalXP(let xp):
            return snapshot.totalXP >= xp
        }
    }
}

/// A milestone boss. While active it replaces all normal spawns and can only
/// be defeated by completing its milestone quest.
struct RPGBoss: Identifiable, Equatable, Sendable {
    enum DifficultyTier: String, CaseIterable, Sendable {
        case challenger
        case veteran
        case elite
        case nightmare
        case mythic
    }

    let id: String
    let name: String
    /// Player level that awakens this boss.
    let requiredLevel: Int
    let milestoneQuestID: String
    let spriteAsset: String
    let idleStyle: RPGMonster.AnimationStyle
    let attackStyle: RPGMonster.AnimationStyle
    /// Shown in the scene while the fight rages.
    let phaseText: String
    let defeatText: String
    let difficulty: DifficultyTier
    /// Optional background swap while the boss is active.
    let backgroundAsset: String?

    /// Boss frame counts — richer than regular monsters. Must match
    /// scripts/generate_pixel_assets.py (idle 4, attack 4, defeat 5; hit
    /// reuses idle since the scene flashes the sprite instead).
    static func frameCount(for animation: RPGMonster.EnemyAnimation) -> Int {
        switch animation {
        case .idle, .hit: return 4
        case .attack: return 4
        case .defeat: return 5
        }
    }

    /// Asset name for one animation frame. Idle loops; attack/defeat clamp.
    func spriteFrame(_ animation: RPGMonster.EnemyAnimation, index: Int) -> String {
        let anim: RPGMonster.EnemyAnimation = animation == .hit ? .idle : animation
        let count = Self.frameCount(for: anim)
        let frame = anim == .idle
            ? ((index % count) + count) % count
            : min(max(index, 0), count - 1)
        return "\(spriteAsset)_\(anim.rawValue)\(frame)"
    }

    /// Bosses render at 128pt, 1:1 with their 128px source grid.
    var displaySize: CGFloat { 128 }
}
