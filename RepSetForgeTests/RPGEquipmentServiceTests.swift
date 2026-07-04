import XCTest
import SwiftData
@testable import RepSetForge

final class RPGEquipmentServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([OwnedEquipment.self])
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
}
