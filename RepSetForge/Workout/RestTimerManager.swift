import Foundation
import Observation

/// Wall-clock rest timer (§4): pure Date math over the RestLedger — survives
/// backgrounding with no running timer. UI ticks are OS-driven
/// (Text(timerInterval:)); this type only holds state and transitions.
/// Live Activity + local notification wiring lands in Phase 3.
@Observable
@MainActor
final class RestTimerManager {
    private(set) var ledger = RestLedger()

    var isResting: Bool { ledger.isResting }
    var plannedEnd: Date? { ledger.currentPlannedEnd }
    var plannedTotal: TimeInterval { ledger.currentPlannedTotal }
    var restStart: Date? {
        guard let end = ledger.currentPlannedEnd else { return nil }
        return end.addingTimeInterval(-ledger.currentPlannedTotal)
    }

    var onStateChange: (() -> Void)?

    func start(duration: TimeInterval) {
        ledger.startRest(duration: duration)
        onStateChange?()
    }

    func extend(_ delta: TimeInterval = 30) {
        ledger.extendRest(by: delta)
        onStateChange?()
    }

    func skip() {
        ledger.endRest()
        onStateChange?()
    }

    func cumulativeRest(at now: Date = .now) -> TimeInterval {
        ledger.cumulativeRest(at: now)
    }

    func cumulativeWork(sessionStart: Date, at now: Date = .now) -> TimeInterval {
        ledger.cumulativeWork(sessionStart: sessionStart, at: now)
    }

    func reset() {
        ledger = RestLedger()
    }
}
