import XCTest
import SwiftData
@testable import RepSetForge

final class EquipmentDropServiceTests: XCTestCase {
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

    func testNoDropBeforeMilestone() {
        let drop = EquipmentDropService.checkQuestMilestone(completedQuestCount: 2, rpgClass: .knight, context: context)
        XCTAssertNil(drop)
    }

    func testDropsOnQuestMilestone() {
        let drop = EquipmentDropService.checkQuestMilestone(completedQuestCount: 3, rpgClass: .knight, context: context)
        XCTAssertNotNil(drop)
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        XCTAssertEqual(owned.count, 1)
        XCTAssertEqual(owned.first?.purchaseSource, EquipmentDropService.questDropSource)
        XCTAssertEqual(owned.first?.equipmentID, drop?.equipmentID)
    }

    func testDropsOnPRMilestone() {
        let drop = EquipmentDropService.checkPRMilestone(totalPRCount: 6, rpgClass: .mage, context: context)
        XCTAssertNotNil(drop)
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        XCTAssertEqual(owned.first?.purchaseSource, EquipmentDropService.prDropSource)
    }

    func testDropOnlyGrantsClassUsableItems() {
        // Repeatedly drop for a mage and ensure every granted item is mage-usable.
        for milestone in stride(from: 3, through: 30, by: 3) {
            EquipmentDropService.checkQuestMilestone(completedQuestCount: milestone, rpgClass: .mage, context: context)
        }
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        for record in owned {
            let equipment = try! XCTUnwrap(RPGEquipmentRegistry.equipment(id: record.equipmentID))
            XCTAssertTrue(equipment.classes.contains(.mage))
        }
    }

    func testDropNeverGrantsAlreadyOwnedItemAndStopsWhenExhausted() {
        var grantedCount = 0
        for milestone in stride(from: 3, through: 300, by: 3) {
            if EquipmentDropService.checkQuestMilestone(completedQuestCount: milestone, rpgClass: .knight, context: context) != nil {
                grantedCount += 1
            }
        }
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        let uniqueIDs = Set(owned.map(\.equipmentID))
        XCTAssertEqual(owned.count, uniqueIDs.count) // never duplicated
        let knightUsableCount = RPGEquipmentRegistry.all.filter { $0.classes.contains(.knight) }.count
        XCTAssertLessThanOrEqual(grantedCount, knightUsableCount) // stops once exhausted
    }

    func testZeroMilestoneCountNeverDrops() {
        XCTAssertNil(EquipmentDropService.checkQuestMilestone(completedQuestCount: 0, rpgClass: .knight, context: context))
        XCTAssertNil(EquipmentDropService.checkPRMilestone(totalPRCount: 0, rpgClass: .knight, context: context))
    }

    func testPRMilestoneDeterministicAcrossRepeatedCalls() throws {
        // Same determinism guarantee as the quest-milestone version, since
        // ProgressionRebuildService replays PR milestones too on every rebuild.
        let dropA = EquipmentDropService.checkPRMilestone(totalPRCount: 6, rpgClass: .rogue, context: context)

        let schema2 = Schema([OwnedEquipment.self])
        let config2 = ModelConfiguration(schema: schema2, isStoredInMemoryOnly: true)
        let container2 = try ModelContainer(for: schema2, configurations: [config2])
        let context2 = ModelContext(container2)
        let dropB = EquipmentDropService.checkPRMilestone(totalPRCount: 6, rpgClass: .rogue, context: context2)

        XCTAssertEqual(dropA?.equipmentID, dropB?.equipmentID)
    }

    func testQuestAndPRMilestonesAtTheSameCountAreIndependentSeeds() {
        // "quest-3" and "pr-3" are different hash inputs, so a quest-drop and
        // a PR-drop happening to land on the same milestone number is not
        // guaranteed to (nor required to) pick the same item — each check
        // must independently look at its own already-owned set rather than
        // assume the other's pick.
        let questDrop = EquipmentDropService.checkQuestMilestone(completedQuestCount: 3, rpgClass: .knight, context: context)
        let prDrop = EquipmentDropService.checkPRMilestone(totalPRCount: 3, rpgClass: .knight, context: context)

        XCTAssertNotNil(questDrop)
        XCTAssertNotNil(prDrop)
        let owned = (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? []
        XCTAssertEqual(owned.count, 2) // both grants persisted as separate rows, never collapsed into one
    }

    func testDeterministicAcrossRepeatedCalls() throws {
        // Simulates two independent "sessions" hitting the exact same milestone from a clean slate.
        let dropA = EquipmentDropService.checkQuestMilestone(completedQuestCount: 3, rpgClass: .rogue, context: context)

        let schema2 = Schema([OwnedEquipment.self])
        let config2 = ModelConfiguration(schema: schema2, isStoredInMemoryOnly: true)
        let container2 = try ModelContainer(for: schema2, configurations: [config2])
        let context2 = ModelContext(container2)
        let dropB = EquipmentDropService.checkQuestMilestone(completedQuestCount: 3, rpgClass: .rogue, context: context2)

        XCTAssertEqual(dropA?.equipmentID, dropB?.equipmentID)
    }
}
