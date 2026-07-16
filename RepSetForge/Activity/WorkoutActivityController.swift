import ActivityKit
import Foundation
import UserNotifications

@MainActor
final class WorkoutActivityController {
  static let shared = WorkoutActivityController()

  private let notificationID = "repsetforge.rest.complete"

  private init() {}

  func startOrUpdate(attributes: RepSetForgeActivityAttributes, state: RepSetForgeActivityAttributes.ContentState) {
    Task {
      if let activity = Activity<RepSetForgeActivityAttributes>.activities.first {
        await activity.update(ActivityContent(state: state, staleDate: nil))
        return
      }

      do {
        _ = try Activity.request(
          attributes: attributes,
          content: ActivityContent(state: state, staleDate: nil),
          pushType: nil
        )
      } catch {
        // Live Activities can be disabled by the user; the workout UI remains authoritative.
      }
    }
  }

  func update(_ state: RepSetForgeActivityAttributes.ContentState) {
    Task {
      for activity in Activity<RepSetForgeActivityAttributes>.activities {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      }
    }
  }

  func end(summary: RepSetForgeActivityAttributes.ContentState, discard: Bool) {
    Task {
      for activity in Activity<RepSetForgeActivityAttributes>.activities {
        let policy: ActivityUIDismissalPolicy = discard ? .immediate : .after(.now + 4)
        await activity.end(ActivityContent(state: summary, staleDate: nil), dismissalPolicy: policy)
      }
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
  }

  func scheduleRestCompletion(at date: Date, exerciseName: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    guard date > .now else { return }

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

    let content = UNMutableNotificationContent()
    content.title = "Rest complete"
    content.body = exerciseName
    content.sound = .default
    content.interruptionLevel = .timeSensitive

    let interval = max(1, date.timeIntervalSinceNow)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  func cancelRestCompletionNotification() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
  }
}
