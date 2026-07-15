import Foundation
import Observation

/// Wall-clock based rest timer — backed by `Date` math rather than a running
/// `Timer`, so it survives backgrounding (dev spec §4). Views drive their own
/// re-render with `TimelineView(.periodic(...))` and read `remaining(now:)`.
@Observable
final class RestTimerManager {
    private(set) var restEndDate: Date?
    private(set) var restDurationTotal: TimeInterval?
    private(set) var completedRestIntervals: [DateInterval] = []
    private var restStartDate: Date?

    var isResting: Bool { restEndDate != nil }

    func start(duration: TimeInterval, now: Date = .now) {
        finish(now: now)
        restStartDate = now
        restEndDate = now.addingTimeInterval(duration)
        restDurationTotal = duration
    }

    func extend(by seconds: TimeInterval, now: Date = .now) {
        guard let end = restEndDate else { return }
        restEndDate = max(now, end).addingTimeInterval(seconds)
        restDurationTotal = (restDurationTotal ?? 0) + seconds
    }

    func skip(now: Date = .now) {
        finish(now: now)
    }

    func remaining(now: Date = .now) -> TimeInterval {
        guard let end = restEndDate else { return 0 }
        return end.timeIntervalSince(now)
    }

    /// Called when a rest period ends (skip or natural elapse observed by the
    /// caller) so the telemetry header's cumulative REST total stays accurate.
    func finish(now: Date = .now) {
        guard let start = restStartDate else { return }
        completedRestIntervals.append(DateInterval(start: start, end: max(start, now)))
        restStartDate = nil
        restEndDate = nil
        restDurationTotal = nil
    }

    /// Cumulative rest across the session: completed intervals plus the
    /// current running one if a rest is in progress (dev spec §3 telemetry header).
    func cumulativeRest(now: Date = .now) -> TimeInterval {
        var total = completedRestIntervals.reduce(0) { $0 + $1.duration }
        if let start = restStartDate {
            total += now.timeIntervalSince(start)
        }
        return total
    }
}
