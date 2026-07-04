import Foundation

/// A deload/rest-day suggestion derived from recent training patterns —
/// purely informational, never blocks or gates anything.
enum RecoveryRecommendation: Equatable {
    /// Trained streakDays consecutive days with no rest day.
    case restDay(streakDays: Int)
    /// Weekly training volume has climbed for `weeks` consecutive weeks straight.
    case deloadWeek(weeks: Int)
    case allClear

    var title: String {
        switch self {
        case .restDay: return "Consider a Rest Day"
        case .deloadWeek: return "Consider a Deload Week"
        case .allClear: return "All Clear"
        }
    }

    var detail: String {
        switch self {
        case .restDay(let days):
            return "You've trained \(days) days in a row. A rest day helps muscles recover and rebuild stronger."
        case .deloadWeek(let weeks):
            return "Training volume has climbed for \(weeks) weeks straight. A lighter deload week can help you avoid burnout and injury."
        case .allClear:
            return "Your training load and recovery look balanced right now."
        }
    }

    var iconName: String {
        switch self {
        case .restDay: return "bed.double.fill"
        case .deloadWeek: return "arrow.down.right.circle.fill"
        case .allClear: return "checkmark.seal.fill"
        }
    }
}

enum RecoveryRecommendationService {
    /// Consecutive trained days at/above which a rest day is suggested — matches the
    /// existing 7-day streak concept used elsewhere (achievements, boss milestones).
    static let restDayStreakThreshold = 7
    /// Consecutive weeks of strictly rising volume at/above which a deload week is
    /// suggested — a common evidence-based guideline (deload every 3-4 progressive weeks).
    static let deloadConsecutiveRisingWeeks = 3

    /// Rest-day (an acute, immediate signal) takes priority over a deload-week
    /// suggestion (a slower-building trend) when both would apply.
    static func recommendation(from quests: [Quest], calendar: Calendar = .current, now: Date = .now) -> RecoveryRecommendation {
        let completedDates = quests.compactMap { $0.status == .completed ? $0.completedDate : nil }
        let streak = RPGProgressionSnapshot.streak(from: completedDates, calendar: calendar, now: now)
        if streak >= restDayStreakThreshold {
            return .restDay(streakDays: streak)
        }

        let weeklyStats = TrainingChartsService.periodStats(
            from: quests,
            period: .week,
            periodsCount: deloadConsecutiveRisingWeeks + 1,
            calendar: calendar,
            now: now
        )
        if isVolumeRisingConsecutively(weeklyStats) {
            return .deloadWeek(weeks: deloadConsecutiveRisingWeeks)
        }

        return .allClear
    }

    /// True when the most recent `deloadConsecutiveRisingWeeks + 1` weeks each have
    /// nonzero volume strictly greater than the week before — a sustained ramp-up,
    /// not just resuming training after a break.
    private static func isVolumeRisingConsecutively(_ stats: [TrainingPeriodStat]) -> Bool {
        guard stats.count >= deloadConsecutiveRisingWeeks + 1 else { return false }
        let recent = stats.suffix(deloadConsecutiveRisingWeeks + 1)

        var previousVolume: Double?
        for stat in recent {
            guard stat.totalVolume > 0 else { return false }
            if let previousVolume, stat.totalVolume <= previousVolume { return false }
            previousVolume = stat.totalVolume
        }
        return true
    }
}
