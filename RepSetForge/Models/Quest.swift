import Foundation
import SwiftData

/// A workout, framed as an RPG quest. Owns its exercises and, transitively, their sets.
@Model
final class Quest {
    var id: UUID
    var name: String
    var date: Date
    var statusRaw: String
    var totalXP: Int
    var completedDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.quest)
    var exercises: [Exercise] = []

    init(name: String, date: Date = .now, status: QuestStatus = .planned) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.statusRaw = status.rawValue
        self.totalXP = 0
        self.completedDate = nil
    }

    var status: QuestStatus {
        get { QuestStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
}
