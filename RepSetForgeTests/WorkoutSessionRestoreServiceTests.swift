import Testing
import Foundation
@testable import RepSetForge

struct WorkoutSessionRestoreServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeSession(startedHoursAgo: Double, now: Date) -> WorkoutSession {
        let session = WorkoutSession(name: "Test")
        session.startedAt = now.addingTimeInterval(-startedHoursAgo * 3600)
        return session
    }

    @Test func sessionUnderFourHoursIsNotStale() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 3.9, now: now)
        #expect(WorkoutSessionRestoreService.isStale(session, now: now) == false)
    }

    @Test func sessionAtFourHoursIsStale() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 4, now: now)
        #expect(WorkoutSessionRestoreService.isStale(session, now: now))
    }

    @Test func sessionUnderTwelveHoursSameDayDoesNotStronglySuggestFinish() {
        // 1_800_000_000 UTC is a Sunday afternoon; 5h earlier is still the same day.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 5, now: now)
        #expect(WorkoutSessionRestoreService.stronglySuggestsFinish(session, now: now, calendar: calendar) == false)
    }

    @Test func sessionOverTwelveHoursStronglySuggestsFinish() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 13, now: now)
        #expect(WorkoutSessionRestoreService.stronglySuggestsFinish(session, now: now, calendar: calendar))
    }

    @Test func sessionThatCrossedMidnightStronglySuggestsFinishEvenUnderTwelveHours() {
        let cal = calendar
        // Start just before midnight, "now" just after — under 12h elapsed but a new calendar day.
        let startedAt = cal.date(from: DateComponents(year: 2026, month: 7, day: 14, hour: 23, minute: 30))!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 1, minute: 0))!
        let session = WorkoutSession(name: "Test")
        session.startedAt = startedAt
        #expect(WorkoutSessionRestoreService.stronglySuggestsFinish(session, now: now, calendar: cal))
    }

    @Test func finishAsIsUsesLastCompletedSetTimestamp() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 5, now: now)
        let exercise = Exercise(name: "Bench Press")
        let sessionExercise = SessionExercise(exercise: exercise, order: 0)
        let earlierSet = SetEntry(index: 0, weightKg: 100, reps: 5)
        earlierSet.completedAt = now.addingTimeInterval(-3600)
        let latestSet = SetEntry(index: 1, weightKg: 100, reps: 5)
        latestSet.completedAt = now.addingTimeInterval(-1800)
        sessionExercise.setEntries = [earlierSet, latestSet]
        session.sessionExercises = [sessionExercise]

        #expect(WorkoutSessionRestoreService.finishAsIsEndedAt(session) == latestSet.completedAt)
    }

    @Test func finishAsIsFallsBackToStartedAtWhenNoSetsLogged() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = makeSession(startedHoursAgo: 5, now: now)
        #expect(WorkoutSessionRestoreService.finishAsIsEndedAt(session) == session.startedAt)
    }
}
