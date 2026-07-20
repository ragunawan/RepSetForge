import Testing
@testable import RepSetForge

struct PlateCalcTests {
    let standard: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    @Test func exactBreakdown() throws {
        // 100 kg on a 20 kg bar → 40 per side = 25 + 15.
        let b = try #require(PlateCalc.breakdown(targetKg: 100, barKg: 20, plates: standard))
        #expect(b.perSide.map { $0.plateKg } == [25, 15])
        #expect(b.perSide.map { $0.count } == [1, 1])
        #expect(b.remainderKg == 0)
    }

    @Test func repeatedPlates() throws {
        // 170 kg → 75 per side = 25×3.
        let b = try #require(PlateCalc.breakdown(targetKg: 170, barKg: 20, plates: standard))
        #expect(b.perSide.first?.plateKg == 25)
        #expect(b.perSide.first?.count == 3)
        #expect(b.remainderKg == 0)
    }

    @Test func barOnly() throws {
        let b = try #require(PlateCalc.breakdown(targetKg: 20, barKg: 20, plates: standard))
        #expect(b.perSide.isEmpty)
        #expect(b.remainderKg == 0)
    }

    @Test func belowBarIsNil() {
        #expect(PlateCalc.breakdown(targetKg: 15, barKg: 20, plates: standard) == nil)
    }

    @Test func unbuildableRemainder() throws {
        // 22 kg → 1 per side; smallest plate is 1.25, so nothing fits.
        let b = try #require(PlateCalc.breakdown(targetKg: 22, barKg: 20, plates: standard))
        #expect(b.remainderKg == 1)
    }

    @Test func limitedInventoryFallsThrough() throws {
        // Only 5s available: 100 kg → 40 per side = 5×8.
        let b = try #require(PlateCalc.breakdown(targetKg: 100, barKg: 20, plates: [5]))
        #expect(b.perSide.count == 1)
        #expect(b.perSide.first?.plateKg == 5)
        #expect(b.perSide.first?.count == 8)
        #expect(b.remainderKg == 0)
    }
}
