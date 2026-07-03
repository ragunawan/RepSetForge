import Foundation

/// Determines the right lifecycle status for a quest based on the calendar
/// day it's scheduled for, so creating a quest for today, a future date, or a
/// past date (backdating a workout already done) all "just work."
enum QuestScheduler {
    /// Quests dated on a future calendar day start `.planned`; quests dated
    /// today or earlier start `.active` so backdated workouts can be logged
    /// and completed immediately.
    static func status(for date: Date, calendar: Calendar = .current) -> QuestStatus {
        let today = calendar.startOfDay(for: .now)
        let scheduledDay = calendar.startOfDay(for: date)
        return scheduledDay > today ? .planned : .active
    }
}
