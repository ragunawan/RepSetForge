import Foundation
import SwiftData

@Model
final class SetEntry {
    var id: UUID = UUID()
    var index: Int = 0
    var type: SetType = SetType.working
    var weightKg: Decimal?
    var reps: Int?
    var rpe: Double?
    var completedAt: Date?
    /// Denormalized so a set row can render a PR badge without a `PRRecord` lookup (dev spec §2).
    var isPR: Bool = false

    var sessionExercise: SessionExercise?

    init(index: Int, type: SetType = .working, weightKg: Decimal? = nil, reps: Int? = nil, rpe: Double? = nil) {
        self.id = UUID()
        self.index = index
        self.type = type
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
    }

    /// Epley estimated 1RM: w × (1 + r/30), capped at reps ≤ 12 for validity (dev spec §2).
    /// This is a pure function of weight/reps — callers filter by `SetType.countsTowardVolumeAndPRs`.
    var estimatedOneRepMax: Decimal? {
        guard let weightKg, let reps, reps > 0, reps <= 12 else { return nil }
        return weightKg * (1 + Decimal(reps) / 30)
    }

    var volumeKg: Decimal? {
        guard let weightKg, let reps else { return nil }
        return weightKg * Decimal(reps)
    }
}
