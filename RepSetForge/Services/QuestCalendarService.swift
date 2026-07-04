import Foundation

/// Pure calendar-grid and day-bucketing helpers behind the History tab's
/// calendar view — no persisted state of its own.
enum QuestCalendarService {
    /// Buckets completed quests by calendar day (start-of-day) for lookup by
    /// a calendar cell.
    static func groupedByDay(_ quests: [Quest], calendar: Calendar = .current) -> [Date: [Quest]] {
        let completed = quests.filter { $0.status == .completed && $0.completedDate != nil }
        return Dictionary(grouping: completed) { calendar.startOfDay(for: $0.completedDate!) }
    }

    /// A full 6-week (42-day) grid for the month containing `date`, padded
    /// with adjacent-month dates so every row is a complete week starting on
    /// `calendar.firstWeekday`.
    static func monthGrid(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingEmptyDays, to: firstOfMonth) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }
}
