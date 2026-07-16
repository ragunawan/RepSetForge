import ActivityKit
import Foundation

struct RepSetForgeActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    enum RestPhase: Codable, Hashable {
      case working
      case resting(end: Date, total: TimeInterval)
    }

    var currentExerciseName: String
    var setIndex: Int
    var setTotal: Int
    var sessionSetCount: Int
    var sessionSetTotal: Int
    var restPhase: RestPhase
    var volumeKg: Decimal
    var prCount: Int
    var summaryLine: String?
  }

  var workoutName: String
  var startedAt: Date
}
