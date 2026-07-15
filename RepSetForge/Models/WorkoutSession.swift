import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var name: String = ""
    var routine: Routine?
    var startedAt: Date = Date.now
    var endedAt: Date?
    var notes: String?
    var status: WorkoutSessionStatus = WorkoutSessionStatus.active
    /// Links to the `HKWorkout` written on completion (dev spec §4b); edits update rather
    /// than insert, and deleting the session deletes the linked HKWorkout.
    var healthKitUUID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    private var _sessionExercises: [SessionExercise]? = []
    var sessionExercises: [SessionExercise] {
        get { _sessionExercises ?? [] }
        set { _sessionExercises = newValue }
    }

    init(name: String, routine: Routine? = nil) {
        self.id = UUID()
        self.name = name
        self.routine = routine
        self.startedAt = .now
        self.status = .active
    }
}
