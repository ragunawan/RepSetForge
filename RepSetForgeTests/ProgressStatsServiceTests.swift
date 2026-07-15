import Testing
import Foundation
@testable import RepSetForge

struct ProgressStatsServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func makeSession(
        daysAgo: Int,
        now: Date,
        calendar: Calendar,
        exercise: Exercise,
        weightKg: Decimal = 100,
        reps: Int = 8
    ) -> WorkoutSession {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let session = WorkoutSession(name: "Test")
        session.startedAt = date
        session.status = .completed
        let sessionExercise = SessionExercise(exercise: exercise, order: 0)
        let set = SetEntry(index: 0, weightKg: weightKg, reps: reps)
        set.completedAt = date
        sessionExercise.setEntries = [set]
        session.sessionExercises = [sessionExercise]
        return session
    }

    @Test func averageSessionsPerWeekCountsOnlySessionsWithinThePeriod() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        let bench = Exercise(name: "Bench Press")
        let recent = makeSession(daysAgo: 1, now: now, calendar: cal, exercise: bench)
        let old = makeSession(daysAgo: 60, now: now, calendar: cal, exercise: bench) // outside a 4-week period

        let summary = ProgressStatsService.summary(
            period: .fourWeeks,
            completedSessions: [recent, old],
            prRecords: [],
            now: now,
            calendar: cal
        )

        #expect(summary.averageSessionsPerWeek == 1.0 / 4.0)
    }

    @Test func weeklyVolumesHasOneEntryPerWeekInThePeriod() {
        let now = Date.now
        let cal = calendar
        let summary = ProgressStatsService.summary(
            period: .fourWeeks,
            completedSessions: [],
            prRecords: [],
            now: now,
            calendar: cal
        )

        #expect(summary.weeklyVolumes.count == 4)
    }

    @Test func muscleSetsPerWeekAggregatesAcrossSessionsAndSortsDescending() {
        let now = Date.now
        let cal = calendar
        let bench = Exercise(name: "Bench Press", muscleGroups: [.chest, .triceps])
        let squat = Exercise(name: "Squat", muscleGroups: [.quads])

        let session1 = makeSession(daysAgo: 1, now: now, calendar: cal, exercise: bench)
        let session2 = makeSession(daysAgo: 2, now: now, calendar: cal, exercise: bench)
        let session3 = makeSession(daysAgo: 3, now: now, calendar: cal, exercise: squat)

        let summary = ProgressStatsService.summary(
            period: .fourWeeks,
            completedSessions: [session1, session2, session3],
            prRecords: [],
            now: now,
            calendar: cal
        )

        let chest = summary.muscleSetsPerWeek.first { $0.muscle == .chest }
        let quads = summary.muscleSetsPerWeek.first { $0.muscle == .quads }

        #expect(chest?.setsPerWeek == 2.0 / 4.0) // 2 bench sessions, 1 set each, over 4 weeks
        #expect(quads?.setsPerWeek == 1.0 / 4.0)
        // Chest (2 qualifying sets) should sort ahead of quads (1 qualifying set).
        #expect(summary.muscleSetsPerWeek.first?.muscle == .chest)
    }

    @Test func prCountOnlyCountsRecordsWithinThePeriod() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = calendar
        let bench = Exercise(name: "Bench Press")
        let recentPR = PRRecord(exercise: bench, kind: .bestWeight, value: 100, achievedAt: now)
        let oldPR = PRRecord(exercise: bench, kind: .bestWeight, value: 90, achievedAt: cal.date(byAdding: .day, value: -60, to: now)!)

        let summary = ProgressStatsService.summary(
            period: .fourWeeks,
            completedSessions: [],
            prRecords: [recentPR, oldPR],
            now: now,
            calendar: cal
        )

        #expect(summary.prCount == 1)
    }
}
