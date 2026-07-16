import ActivityKit
import SwiftUI
import WidgetKit

struct RepSetForgeActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var exerciseName: String
    var restEndsAt: Date?
  }

  var sessionName: String
}

struct RepSetForgeLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RepSetForgeActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        Text(context.attributes.sessionName)
          .font(.system(size: 14, weight: .bold, design: .monospaced))
        Text(context.state.exerciseName)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
      }
      .padding()
      .activityBackgroundTint(Color.black)
      .activitySystemActionForegroundColor(Color.green)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.exerciseName)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
      } compactLeading: {
        Text("RSF")
      } compactTrailing: {
        Text("REST")
      } minimal: {
        Text("R")
      }
    }
  }
}
