import Foundation
import SwiftData

@Model
final class PRRecord {
    var id: UUID = UUID()
    var kind: PRKind = PRKind.bestWeight
    var value: Decimal = 0
    var achievedAt: Date = Date.now

    var exercise: Exercise?
    var setEntry: SetEntry?

    init(exercise: Exercise?, kind: PRKind, value: Decimal, setEntry: SetEntry? = nil, achievedAt: Date = .now) {
        self.id = UUID()
        self.exercise = exercise
        self.kind = kind
        self.value = value
        self.setEntry = setEntry
        self.achievedAt = achievedAt
    }
}
