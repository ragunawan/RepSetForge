import Foundation
import SwiftData

@Model
final class SessionExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var groupID: UUID?
    var note: String?

    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    private var _setEntries: [SetEntry]? = []
    var setEntries: [SetEntry] {
        get { _setEntries ?? [] }
        set { _setEntries = newValue }
    }

    init(exercise: Exercise?, order: Int, groupID: UUID? = nil, note: String? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.groupID = groupID
        self.note = note
    }
}
