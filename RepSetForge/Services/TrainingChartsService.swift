import Foundation

enum ChartPeriod {
    case week
    case month

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

/// One period's (week or month) aggregated training stats — pure and
/// derived from completed-quest history, no persisted state of its own.
struct TrainingPeriodStat: Identifiable, Equatable {
    var id: Date { periodStart }
    let periodStart: Date
    let totalXP: Int
    /// Total reps × weight across all completed sets, normalized to pounds
    /// regardless of which unit each set was logged in.
    let totalVolume: Double
    /// Distinct calendar days with at least one completed quest in this period.
    let daysTrained: Int
}

enum TrainingChartsService {
    /// Builds the last `periodsCount` weeks or months (oldest first, ending
    /// with the period containing `now`), each with aggregated XP, volume,
    /// and days-trained — including periods with zero activity, so a chart
    /// never silently skips a quiet week/month.
    static func periodStats(
        from quests: [Quest],
        period: ChartPeriod,
        periodsCount: Int,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [TrainingPeriodStat] {
        guard periodsCount > 0, let currentInterval = calendar.dateInterval(of: period.calendarComponent, for: now) else {
            return []
        }

        var intervals: [DateInterval] = [currentInterval]
        while intervals.count < periodsCount {
            guard let previousStart = calendar.date(byAdding: period.calendarComponent, value: -1, to: intervals[0].start),
                  let previousInterval = calendar.dateInterval(of: period.calendarComponent, for: previousStart)
            else { break }
            intervals.insert(previousInterval, at: 0)
        }

        let completed = quests.filter { $0.status == .completed && $0.completedDate != nil }

        return intervals.map { interval in
            let questsInPeriod = completed.filter { quest in
                guard let date = quest.completedDate else { return false }
                return interval.contains(date)
            }

            let totalXP = questsInPeriod.reduce(0) { $0 + $1.totalXP }

            let totalVolume = questsInPeriod.reduce(0.0) { sum, quest in
                sum + quest.exercises.reduce(0.0) { exerciseSum, exercise in
                    exerciseSum + exercise.completedSets.reduce(0.0) { setSum, set in
                        setSum + Double(set.reps) * set.weightUnit.convert(set.weight, to: .pounds)
                    }
                }
            }

            let daysTrained = Set(questsInPeriod.compactMap { $0.completedDate.map { calendar.startOfDay(for: $0) } }).count

            return TrainingPeriodStat(periodStart: interval.start, totalXP: totalXP, totalVolume: totalVolume, daysTrained: daysTrained)
        }
    }
}
