import Foundation
import SwiftData

@Model
final class RoutineItem {
    var id: UUID = UUID()
    var order: Int = 0
    /// Items sharing a `groupID` form a superset/circuit — rendered as one page,
    /// one card per member (dev spec §3 "Supersets in the paged view").
    var groupID: UUID?
    var targetSets: Int = 3
    var targetRepsLow: Int = 8
    var targetRepsHigh: Int = 12
    var targetRPE: Double?
    var restSeconds: Int = 90
    var note: String?

    var routine: Routine?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade)
    var progressionRule: ProgressionRule?

    init(
        exercise: Exercise?,
        order: Int,
        groupID: UUID? = nil,
        targetSets: Int = 3,
        targetRepsLow: Int = 8,
        targetRepsHigh: Int = 12,
        targetRPE: Double? = nil,
        restSeconds: Int = 90,
        note: String? = nil,
        progressionRule: ProgressionRule? = nil
    ) {
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.groupID = groupID
        self.targetSets = targetSets
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.note = note
        self.progressionRule = progressionRule
    }
}
