import ActivityKit
import Foundation

/// §4 attributes/state. Static: workout name + start date. ContentState is
/// pushed on set completion, rest transitions, and page change only — all
/// ticking rendering is OS-driven in the widget views.
/// Compiled into BOTH the app and widget-extension targets.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setIndex: Int
        var setTotal: Int
        var sessionSetCount: Int
        var sessionSetTotal: Int
        /// nil = working; non-nil = resting until `restEnd` of `restTotal`.
        var restEnd: Date?
        var restTotal: TimeInterval?
        var volumeKg: Double

        var isResting: Bool { restEnd != nil }
        var restStart: Date? {
            guard let restEnd, let restTotal else { return nil }
            return restEnd.addingTimeInterval(-restTotal)
        }
    }

    var workoutName: String
    var startDate: Date
}
