import Foundation
import UserNotifications

/// Local notification at rest completion when backgrounded (dev spec §3/§4).
/// `RestTimerManager` stays pure Date-math with no UIKit/UserNotifications
/// dependency (see its own doc comment) — this is driven externally by the
/// caller observing `restEndDate` changes and calling `reschedule(endDate:)`.
///
/// No extra Info.plist usage string or entitlement is needed for local
/// (as opposed to remote/push) notifications — just the runtime
/// authorization prompt. iOS suppresses banner/sound presentation for a
/// fired local notification while the app is foregrounded unless a
/// `UNUserNotificationCenterDelegate` opts in, which gives "only when
/// backgrounded" for free without one.
enum RestTimerNotificationScheduler {
    private static let identifier = "rest-timer-complete"

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Reschedules the pending rest-complete notification to fire at
    /// `endDate`; pass `nil` to cancel (rest skipped or finished). Always
    /// clears any existing pending request first so Start/Extend/Skip each
    /// just call this with the timer's current `restEndDate` rather than
    /// needing separate schedule/cancel/reschedule call sites.
    static func reschedule(endDate: Date?, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let endDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let interval = max(1, endDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}
