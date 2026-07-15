import ActivityKit
import Foundation

struct RepSetForgeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: Codable, Hashable {
            case working
            case resting(end: Date, total: TimeInterval)
        }

        var currentExerciseName: String
        var setIndex: Int
        var setTotal: Int
        var sessionSetCount: Int
        var sessionSetTotal: Int
        var phase: Phase
        var volumeKg: Double
        var ended: Bool = false
    }

    var workoutName: String
    var startedAt: Date
}
