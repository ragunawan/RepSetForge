import Foundation

/// A regular enemy that can appear in the passive Home scene. Which monsters
/// spawn is driven entirely by the player's current level band.
struct RPGMonster: Identifiable, Equatable, Sendable {
    enum Rarity: String, CaseIterable, Sendable {
        case common
        case uncommon
        case rare
        case elite

        /// Relative spawn weight inside a level band's pool.
        var spawnWeight: Int {
            switch self {
            case .common: return 60
            case .uncommon: return 25
            case .rare: return 12
            case .elite: return 3
            }
        }
    }

    enum AnimationStyle: String, Sendable {
        case bounce     // slimes, imps
        case hover      // bats, wraiths
        case shamble    // skeletons, rats, goblins
        case stomp      // golems, orcs, big beasts
        case flicker    // spectral flicker
    }

    let id: String
    let name: String
    let family: String
    /// Player level at which this monster enters the spawn pool.
    let minLevel: Int
    /// Player level after which it stops spawning; nil = never retired.
    let maxLevel: Int?
    let rarity: Rarity
    let spriteAsset: String
    let idleStyle: AnimationStyle
    let attackStyle: AnimationStyle
    /// 1–10 rating that scales how many hits the monster takes to defeat.
    let threat: Int
    let behaviorText: String

    func spawns(atLevel level: Int) -> Bool {
        level >= minLevel && (maxLevel.map { level <= $0 } ?? true)
    }

    /// Enemy animation kinds. Frame counts must match scripts/generate_pixel_assets.py.
    enum EnemyAnimation: String, Sendable {
        case idle
        case attack
        case hit
        case defeat

        /// Frames for regular monsters (bosses have their own counts).
        var monsterFrameCount: Int {
            switch self {
            case .idle: return 3
            case .attack: return 2
            case .hit: return 1
            case .defeat: return 3
            }
        }
    }

    /// Asset name for one animation frame. Idle loops; attack/hit/defeat clamp.
    func spriteFrame(_ animation: EnemyAnimation, index: Int) -> String {
        let count = animation.monsterFrameCount
        let frame = animation == .idle
            ? ((index % count) + count) % count
            : min(max(index, 0), count - 1)
        return "\(spriteAsset)_\(animation.rawValue)\(frame)"
    }

    /// Point size the scene renders this monster at, matched 1:1 to the source
    /// pixel grid so sprites never stretch: small 48, medium 64, large 80.
    var displaySize: CGFloat {
        if threat <= 3 { return 48 }
        if threat <= 7 { return 64 }
        return 80
    }
}
