import Foundation

/// Restore branching per §1: unfinished session on launch —
/// < 4 h old → silent resume; ≥ 4 h → sheet (Resume / Finish-as-is / Discard);
/// crossed midnight or exceeds 12 h → sheet with Finish-as-is pre-suggested,
/// committing endedAt = last set's completedAt. Never silently delete sets.
enum SessionRestoreAction: Equatable {
    case silentResume
    case promptSheet(suggestFinishAsIs: Bool)
}

enum SessionRestorePolicy {
    static let silentResumeWindow: TimeInterval = 4 * 3600
    static let autoFinishThreshold: TimeInterval = 12 * 3600

    static func action(startedAt: Date, now: Date, calendar: Calendar = .current) -> SessionRestoreAction {
        let age = now.timeIntervalSince(startedAt)
        let crossedMidnight = !calendar.isDate(startedAt, inSameDayAs: now)
        let suggestFinish = age >= autoFinishThreshold || crossedMidnight
        if age < silentResumeWindow && !suggestFinish {
            return .silentResume
        }
        return .promptSheet(suggestFinishAsIs: suggestFinish)
    }

    /// Finish-as-is endedAt: the last completed set's timestamp, else startedAt.
    static func finishAsIsEnd(startedAt: Date, lastSetCompletedAt: Date?) -> Date {
        lastSetCompletedAt ?? startedAt
    }
}
