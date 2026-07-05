import ActivityKit
import Foundation

/// Starts, updates, and ends the Live Activity showing progress on the
/// quest currently being logged. Phone-only — the widget extension only
/// ever renders what this publishes, never starts one itself.
enum LiveActivityService {
    /// Starts a new activity if none is running yet, or updates the
    /// existing one otherwise — the one entry point call sites use on every
    /// set completion, so they don't need to track whether an activity
    /// already exists.
    static func startOrUpdate(
        questName: String,
        completedSetCount: Int,
        totalSetCount: Int,
        restEndDate: Date? = nil
    ) async {
        let state = RepSetForgeActivityAttributes.ContentState(
            completedSetCount: completedSetCount,
            totalSetCount: totalSetCount,
            restEndDate: restEndDate
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if let existing = Activity<RepSetForgeActivityAttributes>.activities.first {
            await existing.update(content)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RepSetForgeActivityAttributes(questName: questName)
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    /// Ends every running activity for this app. There's only ever at most
    /// one (one active quest at a time), but this stays defensively correct
    /// if that ever changes.
    static func endAll() async {
        for activity in Activity<RepSetForgeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
