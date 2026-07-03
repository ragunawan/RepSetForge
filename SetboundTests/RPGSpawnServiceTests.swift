import XCTest
@testable import Setbound

final class RPGSpawnServiceTests: XCTestCase {

    // MARK: Spawn pool by level

    func testLevelOnePoolContainsOnlyStarterMonsters() {
        let ids = Set(MonsterSpawnService.spawnPool(forLevel: 1).map(\.id))
        XCTAssertEqual(ids, ["training_slime", "tiny_bat"])
    }

    func testLevelBandBoundaries() {
        // Level 4 is still the starter band; level 5 rolls over to the next.
        XCTAssertTrue(MonsterSpawnService.spawnPool(forLevel: 4).contains { $0.id == "training_slime" })
        XCTAssertFalse(MonsterSpawnService.spawnPool(forLevel: 5).contains { $0.id == "training_slime" })
        XCTAssertTrue(MonsterSpawnService.spawnPool(forLevel: 5).contains { $0.id == "forest_slime" })
    }

    func testMidLevelPoolMatchesTable() {
        let ids = Set(MonsterSpawnService.spawnPool(forLevel: 12).map(\.id))
        XCTAssertEqual(ids, ["goblin_warrior", "bone_rat", "wild_imp"])
    }

    func testEndgamePoolHasNoLevelCap() {
        let expected: Set<String> = ["ancient_golem", "abyss_wraith", "elder_dragonling", "infernal_beast"]
        XCTAssertEqual(Set(MonsterSpawnService.spawnPool(forLevel: 50).map(\.id)), expected)
        XCTAssertEqual(Set(MonsterSpawnService.spawnPool(forLevel: 99).map(\.id)), expected)
    }

    func testEveryLevelHasNonEmptyPool() {
        for level in 1...80 {
            XCTAssertFalse(
                MonsterSpawnService.spawnPool(forLevel: level).isEmpty,
                "Empty spawn pool at level \(level)"
            )
        }
    }

    // MARK: Rarity-weighted selection

    func testRandomMonsterRespectsRarityWeights() {
        var rng = SeededRandomNumberGenerator(seed: 42)
        var counts: [String: Int] = [:]
        for _ in 0..<2000 {
            if let monster = MonsterSpawnService.randomMonster(forLevel: 50, using: &rng) {
                counts[monster.id, default: 0] += 1
            }
        }
        let common = counts["ancient_golem"] ?? 0        // weight 60
        let uncommon = counts["abyss_wraith"] ?? 0       // weight 25
        let rare = counts["elder_dragonling"] ?? 0       // weight 12
        let elite = counts["infernal_beast"] ?? 0        // weight 3

        XCTAssertGreaterThan(common, uncommon)
        XCTAssertGreaterThan(uncommon, rare)
        XCTAssertGreaterThan(rare, elite)
        XCTAssertGreaterThan(elite, 0, "Elite monsters should still appear occasionally")
    }

    func testRandomMonsterOnlyPicksFromLevelPool() {
        var rng = SeededRandomNumberGenerator(seed: 7)
        for _ in 0..<200 {
            let monster = MonsterSpawnService.randomMonster(forLevel: 8, using: &rng)
            XCTAssertNotNil(monster)
            XCTAssertTrue(monster!.spawns(atLevel: 8), "\(monster!.id) should not spawn at level 8")
        }
    }

    func testSeededGeneratorIsDeterministic() {
        var first = SeededRandomNumberGenerator(seed: 99)
        var second = SeededRandomNumberGenerator(seed: 99)
        let a = (0..<20).compactMap { _ in MonsterSpawnService.randomMonster(forLevel: 25, using: &first)?.id }
        let b = (0..<20).compactMap { _ in MonsterSpawnService.randomMonster(forLevel: 25, using: &second)?.id }
        XCTAssertEqual(a, b)
    }

    // MARK: Boss suppression of normal spawns

    func testActiveBossSuppressesNormalSpawns() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        let boss = RPGBossRegistry.boss(id: "iron_goblin_captain")!
        for _ in 0..<50 {
            let encounter = MonsterSpawnService.nextEncounter(forLevel: 10, activeBoss: boss, using: &rng)
            XCTAssertEqual(encounter, .boss(boss), "Active boss must replace all random encounters")
        }
    }

    func testNoBossYieldsMonsterEncounters() {
        var rng = SeededRandomNumberGenerator(seed: 2)
        let encounter = MonsterSpawnService.nextEncounter(forLevel: 10, activeBoss: nil, using: &rng)
        guard case .monster(let monster)? = encounter else {
            return XCTFail("Expected a monster encounter, got \(String(describing: encounter))")
        }
        XCTAssertTrue(monster.spawns(atLevel: 10))
    }

    // MARK: Registry integrity

    func testMonsterRegistryHasUniqueIDsAndValidBands() {
        let ids = RPGMonsterRegistry.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Monster IDs must be unique")
        XCTAssertEqual(ids.count, 24)
        for monster in RPGMonsterRegistry.all {
            if let max = monster.maxLevel {
                XCTAssertLessThanOrEqual(monster.minLevel, max, "\(monster.id) has an inverted level band")
            }
            XCTAssertTrue((1...10).contains(monster.threat), "\(monster.id) threat out of range")
        }
    }
}
