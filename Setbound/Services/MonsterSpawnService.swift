import Foundation

/// What the passive scene should fight next: a boss locks out normal spawns.
enum RPGEncounter: Equatable {
    case monster(RPGMonster)
    case boss(RPGBoss)
}

/// Deterministic SplitMix64 generator so spawn behavior is testable and
/// previews are stable.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Centralized, level-driven spawn logic. Pure functions so the Home view
/// never embeds spawn rules.
enum MonsterSpawnService {

    /// Every monster eligible at the given player level.
    static func spawnPool(forLevel level: Int, from registry: [RPGMonster] = RPGMonsterRegistry.all) -> [RPGMonster] {
        registry.filter { $0.spawns(atLevel: level) }
    }

    /// Rarity-weighted random pick from the level's spawn pool.
    static func randomMonster<G: RandomNumberGenerator>(
        forLevel level: Int,
        from registry: [RPGMonster] = RPGMonsterRegistry.all,
        using rng: inout G
    ) -> RPGMonster? {
        let pool = spawnPool(forLevel: level, from: registry)
        guard !pool.isEmpty else { return nil }

        let totalWeight = pool.reduce(0) { $0 + $1.rarity.spawnWeight }
        var roll = Int.random(in: 0..<totalWeight, using: &rng)
        for monster in pool {
            roll -= monster.rarity.spawnWeight
            if roll < 0 { return monster }
        }
        return pool.last
    }

    /// The next encounter for the scene. An active boss suppresses all normal
    /// spawning until its milestone quest is completed.
    static func nextEncounter<G: RandomNumberGenerator>(
        forLevel level: Int,
        activeBoss: RPGBoss?,
        using rng: inout G
    ) -> RPGEncounter? {
        if let activeBoss {
            return .boss(activeBoss)
        }
        return randomMonster(forLevel: level, using: &rng).map(RPGEncounter.monster)
    }

    /// Hits needed to defeat a monster in the passive loop, scaled by threat.
    static func hitsToDefeat(_ monster: RPGMonster) -> Int {
        2 + monster.threat / 2
    }
}
