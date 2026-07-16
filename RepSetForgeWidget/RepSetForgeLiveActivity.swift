import ActivityKit
import SwiftUI
import WidgetKit

/// Phase 0 stub. Full attributes/state, lock-screen and Dynamic Island
/// surfaces, and Skip/+30s intents land in Phase 3 (spec §4).
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentExerciseName: String
        var setIndex: Int
        var setTotal: Int
        var sessionSetCount: Int
        var sessionSetTotal: Int
        var isResting: Bool
        var restEnd: Date?
        var restTotal: TimeInterval?
        var volumeKg: Double
    }

    var workoutName: String
    var startDate: Date
}

struct RepSetForgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen / banner — placeholder until Phase 3.
            Text(context.attributes.workoutName)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.workoutName)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 12, design: .monospaced).monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
    }
}
