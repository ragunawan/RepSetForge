import Testing
import Foundation
@testable import RepSetForge

struct HomeStatsServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday, matches the mockup's calendar module
        return cal
    }

    private func makeSession(daysAgo: Int, now: Date, calendar: Calendar, weightKg: Decimal = 100, reps: Int = 8) -> WorkoutSession {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let session = WorkoutSession(name: "Test")
        session.startedAt = date
        session.status = .completed
        let exercise = Exercise(name: "Bench Press")
        let sessionExercise = SessionExercise(exercise: exercise, order: 0)
        let set = SetEntry(index: 0, weightKg: weightKg, reps: reps)
        set.completedAt = date
        sessionExercise.setEntries = [set]
        session.sessionExercises = [sessionExercise]
        return session
    }

    @Test func weeklySummaryCountsOnlyThisWeeksSessions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        let thisWeek = makeSession(daysAgo: 1, now: now, calendar: cal)
        let lastWeek = makeSession(daysAgo: 10, now: now, calendar: cal)

        let summary = HomeStatsService.weeklySummary(completedSessions: [thisWeek, lastWeek], prRecords: [], now: now, calendar: cal)

        #expect(summary.sessionCount == 1)
        #expect(summary.volumeKg == 800)
    }

    @Test func streakCountsConsecutiveWeeksBackward() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        let sessions = [0, 7, 14].map { makeSession(daysAgo: $0, now: now, calendar: cal) }

        #expect(HomeStatsService.currentStreakWeeks(completedSessions: sessions, now: now, calendar: cal) == 3)
    }

    @Test func streakStopsAtFirstMissingWeek() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        // This week and 3 weeks ago, but not 1 or 2 weeks ago — the gap breaks the streak.
        let sessions = [0, 21].map { makeSession(daysAgo: $0, now: now, calendar: cal) }

        #expect(HomeStatsService.currentStreakWeeks(completedSessions: sessions, now: now, calendar: cal) == 1)
    }

    @Test func emptyCurrentWeekDoesNotBreakAnExistingStreak() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        // Nothing logged yet this week, but the two weeks before both have a session.
        let sessions = [7, 14].map { makeSession(daysAgo: $0, now: now, calendar: cal) }

        #expect(HomeStatsService.currentStreakWeeks(completedSessions: sessions, now: now, calendar: cal) == 2)
    }

    @Test func noSessionsYieldsZeroStreak() {
        #expect(HomeStatsService.currentStreakWeeks(completedSessions: [], now: .now, calendar: calendar) == 0)
    }
}
