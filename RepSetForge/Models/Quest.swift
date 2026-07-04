import Foundation
import SwiftData

/// A workout, framed as an RPG quest. Owns its exercises and, transitively, their sets.
@Model
final class Quest {
    // CloudKit requires every SwiftData attribute to be optional or have a
    // default value — these defaults are never actually relied upon since
    // init(...) always sets a real value immediately.
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date.now
    var statusRaw: String = QuestStatus.planned.rawValue
    var totalXP: Int = 0
    var completedDate: Date?
    /// Free-form journal entry for the session as a whole (how it felt, what to change next time).
    var notes: String = ""
    /// Rate of Perceived Exertion for the session as a whole, 1 (very easy) to 10 (max effort). Optional since not every session gets rated.
    var perceivedEffort: Int?

    // CloudKit requires to-many relationships to be Optional at the stored
    // property level — a default value alone (like every other attribute in
    // this file) isn't enough for relationships specifically. This private
    // optional backing + public non-optional computed accessor keeps every
    // other call site in the codebase working with a plain `[Exercise]`,
    // unaware anything changed.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.quest)
    private var exercisesStorage: [Exercise]?

    var exercises: [Exercise] {
        get { exercisesStorage ?? [] }
        set { exercisesStorage = newValue }
    }

    init(name: String, date: Date = .now, status: QuestStatus = .planned) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.statusRaw = status.rawValue
        self.totalXP = 0
        self.completedDate = nil
        self.notes = ""
        self.perceivedEffort = nil
    }

    var status: QuestStatus {
        get { QuestStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
}
