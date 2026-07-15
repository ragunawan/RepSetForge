import Foundation

/// Aggregates completed-session stats for the Home screen's week-at-a-glance
/// module (dev spec §5, mockup frame 1). Pulled out of the view so the
/// streak/week-bucketing logic is testable without SwiftUI.
enum HomeStatsService {
    struct WeeklySummary {
        let sessionCount: Int
        let volumeKg: Decimal
        let setCount: Int
        let prCount: Int
        let streakWeeks: Int
        /// Oldest-to-newest total volume per week, for the sparkline (mockup frame 1).
        let weeklyVolumeSparkline: [Decimal]
    }

    static func weeklySummary(
        completedSessions: [WorkoutSession],
        prRecords: [PRRecord],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklySummary {
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        let thisWeekSessions = completedSessions.filter { weekInterval.contains($0.startedAt) }

        let sets = thisWeekSessions
            .flatMap { $0.sessionExercises.flatMap(\.setEntries) }
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
        let volume = sets.compactMap(\.volumeKg).reduce(Decimal(0), +)
        let prCount = prRecords.filter { weekInterval.contains($0.achievedAt) }.count

        return WeeklySummary(
            sessionCount: thisWeekSessions.count,
            volumeKg: volume,
            setCount: sets.count,
            prCount: prCount,
            streakWeeks: currentStreakWeeks(completedSessions: completedSessions, now: now, calendar: calendar),
            weeklyVolumeSparkline: weeklyVolumes(completedSessions: completedSessions, weeks: 8, now: now, calendar: calendar)
        )
    }

    /// Consecutive weeks with at least one completed session, counting back
    /// from the current week. An empty *current* week doesn't break an
    /// existing streak (the week isn't over yet) — an empty week before that does.
    static func currentStreakWeeks(
        completedSessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        if let currentInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart),
           !completedSessions.contains(where: { currentInterval.contains($0.startedAt) }) {
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return 0 }
            weekStart = previousWeek
        }

        var streak = 0
        while let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) {
            guard completedSessions.contains(where: { interval.contains($0.startedAt) }) else { break }
            streak += 1
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            weekStart = previousWeek
        }
        return streak
    }

    /// Oldest-to-newest total volume per week, going back `weeks` weeks from
    /// the current one. Not `private` — `ProgressStatsService` reuses this
    /// rather than duplicating the bucketing logic for its own range toggle.
    static func weeklyVolumes(
        completedSessions: [WorkoutSession],
        weeks: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Decimal] {
        var result: [Decimal] = []
        var weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        for _ in 0..<weeks {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { break }
            let volume = completedSessions
                .filter { interval.contains($0.startedAt) }
                .flatMap { $0.sessionExercises.flatMap(\.setEntries) }
                .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
                .compactMap(\.volumeKg)
                .reduce(Decimal(0), +)
            result.append(volume)
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            weekStart = previousWeek
        }
        return result.reversed()
    }
}
