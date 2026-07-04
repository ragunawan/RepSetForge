import Foundation

/// The player's current unbroken quest-completion streak, for the widget
/// and (potentially) in-app display. Distinct from
/// `AchievementService`'s streak check, which only asks "is there an
/// unbroken run of at least N days somewhere" for unlock purposes — this
/// answers "how many days long is the streak *right now*," which is a
/// different question (and zero, not just "no", when today and yesterday
/// are both rest days).
enum StreakService {
    /// Start-of-day dates for every quest completion — the same shape
    /// `AchievementService` computes internally, exposed here since the
    /// widget needs it too and that computation is currently private there.
    static func completedDays(from quests: [Quest], calendar: Calendar = .current) -> Set<Date> {
        Set(quests.compactMap { quest -> Date? in
            guard let date = quest.completedDate else { return nil }
            return calendar.startOfDay(for: date)
        })
    }

    /// The current streak length in days, counting back from today. A rest
    /// day *today* doesn't erase yesterday's streak from still displaying
    /// (the player hasn't broken it yet, they just haven't trained today) —
    /// but if neither today nor yesterday has a completion, the streak is 0.
    static func currentStreakLength(completedDays: Set<Date>, asOf referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        var anchor = today
        if !completedDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today), completedDays.contains(yesterday) else {
                return 0
            }
            anchor = yesterday
        }

        var length = 0
        var cursor = anchor
        while completedDays.contains(cursor) {
            length += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return length
    }
}
