import Foundation
import SwiftData

@Model
final class BodyMetric {
    var id: UUID = UUID()
    var date: Date = Date.now
    var bodyweightKg: Decimal?
    var bodyFatPct: Decimal?

    init(date: Date = .now, bodyweightKg: Decimal? = nil, bodyFatPct: Decimal? = nil) {
        self.id = UUID()
        self.date = date
        self.bodyweightKg = bodyweightKg
        self.bodyFatPct = bodyFatPct
    }
}
