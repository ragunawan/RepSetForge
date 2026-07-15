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
    /// Set when the session was started from a routine (dev spec §1 "Start
    /// workout" flow) — lets the progression panel (TODO.md build-order
    /// step 6) find the applicable `ProgressionRule` without threading it
    /// through every call site separately.
    var routineItem: RoutineItem?

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
