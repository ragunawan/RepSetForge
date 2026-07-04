import XCTest
import SwiftData
@testable import RepSetForge

final class RPGEquipmentServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([OwnedEquipment.self, PlayerCharacter.self, RPGEncounterState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testSeedStarterGearGrantsClassWeaponAndUniversalArmor() {
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)

        let owned = RPGEquipmentService.ownedEquipment(context: context)
        XCTAssertTrue(owned.contains { $0.id == "training_sword" })
        XCTAssertTrue(owned.contains { $0.id == "beginner_armor" })
        XCTAssertFalse(owned.contains { $0.id == "focus_staff" }) // mage-only weapon
    }

    func testSeedStarterGearGrantsDifferentWeaponPerClass() {
        RPGEquipmentService.seedStarterGear(for: .mage, context: context)

        let owned = RPGEquipmentService.ownedEquipment(context: context)
        XCTAssertTrue(owned.contains { $0.id == "focus_staff" })
        XCTAssertFalse(owned.contains { $0.id == "training_sword" })
    }

    func testSeedStarterGearIsIdempotent() {
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)
        try? context.save()
        let firstCount = (try? context.fetch(FetchDescriptor<OwnedEquipment>()))?.count ?? -1

        RPGEquipmentService.seedStarterGear(for: .mage, context: context)

        let secondCount = (try? context.fetch(FetchDescriptor<OwnedEquipment>()))?.count ?? -1
        XCTAssertEqual(firstCount, secondCount)
        // Still knight gear, not overwritten by the second (no-op) call.
        let owned = RPGEquipmentService.ownedEquipment(context: context)
        XCTAssertTrue(owned.contains { $0.id == "training_sword" })
    }

    func testStarterGearIsEquippedByDefault() {
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)

        let loadout = RPGEquipmentService.equippedLoadout(context: context)
        XCTAssertEqual(loadout[.weapon]?.id, "training_sword")
        XCTAssertEqual(loadout[.armor]?.id, "beginner_armor")
    }

    func testEquipSwapsWithinSlotAndLeavesOtherSlotsAlone() {
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)
        let axe = OwnedEquipment(equipmentID: "iron_dumbbell_axe", owned: true, equipped: false, purchaseSource: "test")
        context.insert(axe)

        RPGEquipmentService.equip("iron_dumbbell_axe", context: context)

        let loadout = RPGEquipmentService.equippedLoadout(context: context)
        XCTAssertEqual(loadout[.weapon]?.id, "iron_dumbbell_axe")
        XCTAssertEqual(loadout[.armor]?.id, "beginner_armor") // untouched
    }

    func testEquipUnownedItemIsANoOp() {
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)

        RPGEquipmentService.equip("mystic_robe", context: context) // not owned

        let loadout = RPGEquipmentService.equippedLoadout(context: context)
        XCTAssertEqual(loadout[.armor]?.id, "beginner_armor") // unchanged, not swapped to the unowned robe
    }

    // MARK: purchase

    private func makeCharacter(level: Int, gold: Int) -> PlayerCharacter {
        let character = PlayerCharacter(level: level, gold: gold)
        context.insert(character)
        return character
    }

    func testPurchaseSucceedsAndDeductsGold() {
        let character = makeCharacter(level: 1, gold: 100)
        context.insert(RPGEncounterState(rpgClass: .knight))

        let result = RPGEquipmentService.purchase("training_sword", context: context)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(character.gold, 50) // 100 - 50 price
        XCTAssertTrue(RPGEquipmentService.ownedEquipment(context: context).contains { $0.id == "training_sword" })
    }

    func testPurchaseFailsWhenAlreadyOwned() {
        let character = makeCharacter(level: 1, gold: 100)
        context.insert(RPGEncounterState(rpgClass: .knight))
        RPGEquipmentService.seedStarterGear(for: .knight, context: context)

        let result = RPGEquipmentService.purchase("training_sword", context: context)

        XCTAssertEqual(result, .alreadyOwned)
        XCTAssertEqual(character.gold, 100) // untouched
    }

    func testPurchaseFailsWithInsufficientGold() {
        _ = makeCharacter(level: 1, gold: 10)
        context.insert(RPGEncounterState(rpgClass: .knight))

        let result = RPGEquipmentService.purchase("training_sword", context: context)

        XCTAssertEqual(result, .insufficientGold)
        XCTAssertFalse(RPGEquipmentService.ownedEquipment(context: context).contains { $0.id == "training_sword" })
    }

    func testPurchaseFailsWhenLevelLocked() {
        let character = makeCharacter(level: 1, gold: 1000)
        context.insert(RPGEncounterState(rpgClass: .knight))

        let result = RPGEquipmentService.purchase("iron_dumbbell_axe", context: context) // requires level 8

        XCTAssertEqual(result, .levelLocked)
        XCTAssertEqual(character.gold, 1000) // untouched
    }

    func testPurchaseFailsWhenWrongClass() {
        _ = makeCharacter(level: 1, gold: 1000)
        context.insert(RPGEncounterState(rpgClass: .knight))

        let result = RPGEquipmentService.purchase("focus_staff", context: context) // mage-only

        XCTAssertEqual(result, .levelLocked)
    }

    // MARK: rarity

    func testRarityDerivesFromRequiredLevel() {
        XCTAssertEqual(RPGEquipmentRegistry.equipment(id: "training_sword")?.rarity, .common) // level 1
        XCTAssertEqual(RPGEquipmentRegistry.equipment(id: "iron_dumbbell_axe")?.rarity, .uncommon) // level 8
        XCTAssertEqual(RPGEquipmentRegistry.equipment(id: "weighted_vest")?.rarity, .rare) // level 10
        XCTAssertEqual(RPGEquipmentRegistry.equipment(id: "heroic_chestplate")?.rarity, .epic) // level 15
    }
}
