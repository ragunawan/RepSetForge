import ActivityKit
import Foundation
import UserNotifications

/// Owns the workout Live Activity lifecycle (§4). The app never depends on
/// it — start can fail (Live Activities disabled) and the in-app pill stays
/// the source of truth. Also schedules the rest-complete local notification.
@MainActor
final class LiveActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?
    private let notificationID = "rest-complete"

    // MARK: lifecycle

    func start(workoutName: String, startDate: Date, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = WorkoutActivityAttributes(workoutName: workoutName, startDate: startDate)
        activity = try? Activity.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// Finish → linger 4s with the final summary line; Discard → immediate.
    func end(finalState: WorkoutActivityAttributes.ContentState?, immediate: Bool) {
        guard let activity else { return }
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = immediate ? .immediate : .after(.now + 4)
        Task { await activity.end(content, dismissalPolicy: policy) }
        self.activity = nil
    }

    /// §4 reliability: re-assert on foreground if the OS evicted the activity
    /// while a session is live.
    func reassertIfNeeded(workoutName: String, startDate: Date,
                          state: WorkoutActivityAttributes.ContentState) {
        if Activity<WorkoutActivityAttributes>.activities.isEmpty {
            start(workoutName: workoutName, startDate: startDate, state: state)
        } else {
            activity = Activity<WorkoutActivityAttributes>.activities.first
            update(state)
        }
    }

    // MARK: rest-complete local notification (§4, time-sensitive)

    func scheduleRestNotification(endingAt end: Date, exerciseName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = exerciseName
        content.interruptionLevel = .timeSensitive
        content.sound = .default
        let interval = max(1, end.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }

    func cancelRestNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}

extension WorkoutViewModel {
    /// Snapshot the current state for Activity.update() — called on set
    /// completion, rest transitions, and page change only (§4 budget).
    func activityContentState() -> WorkoutActivityAttributes.ContentState {
        let exercises = orderedExercises
        let ex = exercises.indices.contains(page) ? exercises[page] : nil
        let sets = ex.map(orderedSets) ?? []
        let doneHere = sets.filter { $0.completedAt != nil }.count
        return .init(
            exerciseName: ex?.exercise?.name ?? "",
            setIndex: min(doneHere + 1, max(sets.count, 1)),
            setTotal: sets.count,
            sessionSetCount: doneSets,
            sessionSetTotal: totalSets,
            restEnd: restTimer.plannedEnd,
            restTotal: restTimer.isResting ? restTimer.plannedTotal : nil,
            volumeKg: NSDecimalNumber(decimal: volumeKg).doubleValue
        )
    }
}
