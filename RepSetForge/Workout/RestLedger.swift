import Foundation

/// The single source of rest truth (§3.1): WORK and REST both derive from this
/// ledger so they always sum to SESSION. Completed intervals are appended on
/// skip/expiry; the current interval accrues from wall-clock dates.
struct RestLedger: Codable, Equatable {
    struct Interval: Codable, Equatable {
        var start: Date
        var end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    private(set) var completed: [Interval] = []
    /// Wall-clock rest currently running: (start, plannedEnd). Planned end can
    /// pass (overtime); rest keeps accruing until ended.
    private(set) var currentStart: Date?
    private(set) var currentPlannedEnd: Date?
    private(set) var currentPlannedTotal: TimeInterval = 0

    var isResting: Bool { currentStart != nil }

    mutating func startRest(duration: TimeInterval, at now: Date = .now) {
        endRest(at: now) // never two concurrent rests
        currentStart = now
        currentPlannedEnd = now.addingTimeInterval(duration)
        currentPlannedTotal = duration
    }

    mutating func extendRest(by delta: TimeInterval = 30) {
        guard let end = currentPlannedEnd else { return }
        currentPlannedEnd = end.addingTimeInterval(delta)
        currentPlannedTotal += delta
    }

    /// Skip or natural end: banks the interval at its actual wall-clock length.
    mutating func endRest(at now: Date = .now) {
        guard let start = currentStart else { return }
        if now > start {
            completed.append(Interval(start: start, end: now))
        }
        currentStart = nil
        currentPlannedEnd = nil
        currentPlannedTotal = 0
    }

    /// Cumulative REST including the in-flight interval.
    func cumulativeRest(at now: Date = .now) -> TimeInterval {
        let banked = completed.reduce(0) { $0 + $1.duration }
        guard let start = currentStart else { return banked }
        return banked + max(0, now.timeIntervalSince(start))
    }

    /// WORK = SESSION − REST; the invariant WORK + REST == SESSION holds by
    /// construction (both computed from the same ledger and clock).
    func cumulativeWork(sessionStart: Date, at now: Date = .now) -> TimeInterval {
        max(0, now.timeIntervalSince(sessionStart) - cumulativeRest(at: now))
    }

    /// Remaining rest; negative means overtime (+0:12 display).
    func remaining(at now: Date = .now) -> TimeInterval? {
        guard let end = currentPlannedEnd else { return nil }
        return end.timeIntervalSince(now)
    }
}
