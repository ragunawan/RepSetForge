import Foundation

/// Pure staleness/restore logic for `WorkoutSession` (dev spec §1's restore-
/// UX rules), extracted out of `ContentView` so it's unit-testable with
/// fixed reference dates instead of `Date.now`.
enum WorkoutSessionRestoreService {
    static let staleThreshold: TimeInterval = 4 * 3600
    static let veryStaleThreshold: TimeInterval = 12 * 3600

    /// < 4h old resumes silently; >= 4h needs the resolve sheet.
    static func isStale(_ session: WorkoutSession, now: Date = .now) -> Bool {
        now.timeIntervalSince(session.startedAt) >= staleThreshold
    }

    /// "A session that crosses midnight or exceeds 12h auto-suggests
    /// Finish-as-is" (dev spec §1).
    static func stronglySuggestsFinish(_ session: WorkoutSession, now: Date = .now, calendar: Calendar = .current) -> Bool {
        if now.timeIntervalSince(session.startedAt) >= veryStaleThreshold { return true }
        return !calendar.isDate(session.startedAt, inSameDayAs: now)
    }

    /// "Finish as-is (commits with `endedAt` = last set's `completedAt`...)" (dev spec §1).
    /// Falls back to `startedAt` when nothing was ever logged.
    static func finishAsIsEndedAt(_ session: WorkoutSession) -> Date {
        let lastCompletedAt = session.sessionExercises
            .flatMap(\.setEntries)
            .compactMap(\.completedAt)
            .max()
        return lastCompletedAt ?? session.startedAt
    }
}
