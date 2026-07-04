import Foundation

/// One session's worth of a given exercise, aggregated across every matching
/// Exercise instance logged that day (an exercise can appear more than once
/// in a quest, though rarely). Weight/volume are normalized to pounds.
struct ExerciseHistoryPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let maxWeight: Double
    let volume: Double
}

/// Cross-quest metrics for one exercise name — purely derived from completed
/// quest history, no persisted state of its own (unlike `PersonalRecord`,
/// which tracks only the single best-ever value; this keeps the full trend).
struct ExerciseMetrics {
    let exerciseName: String
    /// Chronological, oldest first.
    let history: [ExerciseHistoryPoint]
    let allTimeMaxWeight: Double
    let allTimeBestVolume: Double
}

enum ExerciseMetricsService {
    /// Matches by exercise name, case- and whitespace-insensitively (same
    /// matching rule `PersonalRecordService` uses). Returns nil if the name
    /// is blank or has never been logged in a completed quest.
    static func metrics(for exerciseName: String, in quests: [Quest]) -> ExerciseMetrics? {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let completed = quests.filter { $0.status == .completed && $0.completedDate != nil }

        var points: [ExerciseHistoryPoint] = []
        for quest in completed {
            guard let date = quest.completedDate else { continue }
            let matchingExercises = quest.exercises.filter {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
            }
            guard !matchingExercises.isEmpty else { continue }

            var sessionMaxWeight: Double = 0
            var sessionVolume: Double = 0
            for exercise in matchingExercises {
                for set in exercise.completedSets {
                    let weightInPounds = set.weightUnit.convert(set.weight, to: .pounds)
                    sessionMaxWeight = max(sessionMaxWeight, weightInPounds)
                    sessionVolume += Double(set.reps) * weightInPounds
                }
            }
            guard sessionMaxWeight > 0 || sessionVolume > 0 else { continue }
            points.append(ExerciseHistoryPoint(date: date, maxWeight: sessionMaxWeight, volume: sessionVolume))
        }

        guard !points.isEmpty else { return nil }
        points.sort { $0.date < $1.date }

        return ExerciseMetrics(
            exerciseName: trimmedName,
            history: points,
            allTimeMaxWeight: points.map(\.maxWeight).max() ?? 0,
            allTimeBestVolume: points.map(\.volume).max() ?? 0
        )
    }
}
