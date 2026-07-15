import Foundation
import SwiftData

@Model
final class ProgressionRule {
    var type: ProgressionRuleType = ProgressionRuleType.ladder
    var repRangeLow: Int = 8
    var repRangeHigh: Int = 12
    var maxQualifyingRPE: Double = 9
    var qualifyingSetsRequired: Int = 2
    var incrementKg: Decimal = 2.5

    init(
        type: ProgressionRuleType = .ladder,
        repRangeLow: Int = 8,
        repRangeHigh: Int = 12,
        maxQualifyingRPE: Double = 9,
        qualifyingSetsRequired: Int = 2,
        incrementKg: Decimal = 2.5
    ) {
        self.type = type
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.maxQualifyingRPE = maxQualifyingRPE
        self.qualifyingSetsRequired = qualifyingSetsRequired
        self.incrementKg = incrementKg
    }
}
