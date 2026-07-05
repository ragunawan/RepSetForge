import ActivityKit
import SwiftUI
import WidgetKit

struct RepSetForgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepSetForgeActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.questName)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedSetCount)/\(context.state.totalSetCount)")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let restEndDate = context.state.restEndDate {
                        Text(timerInterval: Date.now...restEndDate, countsDown: true)
                            .font(.title2)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "shield.lefthalf.filled")
            } compactTrailing: {
                Text("\(context.state.completedSetCount)/\(context.state.totalSetCount)")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "shield.lefthalf.filled")
            }
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<RepSetForgeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.questName)
                .font(.headline)
            HStack {
                Text("\(context.state.completedSetCount) / \(context.state.totalSetCount) sets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let restEndDate = context.state.restEndDate {
                    Label {
                        Text(timerInterval: Date.now...restEndDate, countsDown: true)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "hourglass")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
    }
}
