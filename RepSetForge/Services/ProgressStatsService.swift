import Foundation

/// Aggregation for the Progress screen (dev spec §5, mockup frame 8).
/// Reuses `HomeStatsService`'s weekly-volume and streak helpers rather than
/// duplicating that bucketing logic.
enum ProgressStatsService {
    enum Period: String, CaseIterable, Hashable {
        case fourWeeks = "4W"
        case threeMonths = "3M"
        case oneYear = "1Y"

        var weeks: Int {
            switch self {
            case .fourWeeks: return 4
            case .threeMonths: return 13
            case .oneYear: return 52
            }
        }
    }

    struct Summary {
        /// Oldest-to-newest, one entry per week in the selected period.
        let weeklyVolumes: [Decimal]
        let averageSessionsPerWeek: Double
        let streakWeeks: Int
        let prCount: Int
        /// Sorted highest-to-lowest sets/week.
        let muscleSetsPerWeek: [(muscle: MuscleGroup, setsPerWeek: Double)]
    }

    static func summary(
        period: Period,
        completedSessions: [WorkoutSession],
        prRecords: [PRRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let periodStart = calendar.date(byAdding: .weekOfYear, value: -(period.weeks - 1), to: currentWeekStart) ?? currentWeekStart

        let sessionsInPeriod = completedSessions.filter { $0.startedAt >= periodStart }
        let averageSessionsPerWeek = Double(sessionsInPeriod.count) / Double(period.weeks)
        let prCount = prRecords.filter { $0.achievedAt >= periodStart }.count

        var muscleCounts: [MuscleGroup: Int] = [:]
        for sessionExercise in sessionsInPeriod.flatMap(\.sessionExercises) {
            guard let exercise = sessionExercise.exercise else { continue }
            let qualifyingCount = sessionExercise.setEntries
                .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
                .count
            for muscle in exercise.muscleGroups {
                muscleCounts[muscle, default: 0] += qualifyingCount
            }
        }
        let muscleSetsPerWeek = muscleCounts
            .map { (muscle: $0.key, setsPerWeek: Double($0.value) / Double(period.weeks)) }
            .sorted { $0.setsPerWeek > $1.setsPerWeek }

        return Summary(
            weeklyVolumes: HomeStatsService.weeklyVolumes(completedSessions: completedSessions, weeks: period.weeks, now: now, calendar: calendar),
            averageSessionsPerWeek: averageSessionsPerWeek,
            streakWeeks: HomeStatsService.currentStreakWeeks(completedSessions: completedSessions, now: now, calendar: calendar),
            prCount: prCount,
            muscleSetsPerWeek: muscleSetsPerWeek
        )
    }
}
