import Foundation

/// Per-exercise historical aggregation shared by the Exercise Focus chart
/// (dev spec §3) and the Exercise Detail screen (dev spec §5, mockup frame 6).
enum ExerciseHistoryService {
    struct BestStats {
        let bestWeight: Decimal?
        let bestE1RM: Decimal?
        let bestVolumeSet: Decimal?
        let repsAtBestWeight: Int?
    }

    /// Every qualifying (non-warm-up, completed) set logged for `exerciseID`, across all sessions.
    static func qualifyingSets(exerciseID: UUID, in sets: [SetEntry]) -> [SetEntry] {
        sets.filter {
            $0.completedAt != nil
                && $0.type.countsTowardVolumeAndPRs
                && $0.sessionExercise?.exercise?.id == exerciseID
        }
    }

    /// One point per session: that session's best e1RM for the exercise (oldest first).
    static func trendPoints(from qualifyingSets: [SetEntry]) -> [ExerciseTrendChart.Point] {
        let grouped = Dictionary(grouping: qualifyingSets) { $0.sessionExercise?.session?.id }
        let points = grouped.values.compactMap { entries -> ExerciseTrendChart.Point? in
            guard let date = entries.first?.sessionExercise?.session?.startedAt,
                  let bestE1RM = entries.compactMap(\.estimatedOneRepMax).max() else { return nil }
            return ExerciseTrendChart.Point(date: date, e1RM: bestE1RM)
        }
        return points.sorted { $0.date < $1.date }
    }

    static func bestStats(from qualifyingSets: [SetEntry]) -> BestStats {
        let bestWeightSet = qualifyingSets.max { ($0.weightKg ?? -1) < ($1.weightKg ?? -1) }
        return BestStats(
            bestWeight: bestWeightSet?.weightKg,
            bestE1RM: qualifyingSets.compactMap(\.estimatedOneRepMax).max(),
            bestVolumeSet: qualifyingSets.compactMap(\.volumeKg).max(),
            repsAtBestWeight: bestWeightSet?.reps
        )
    }
}
