import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RepSetForgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        RepSetForgeLiveActivityWidget()
    }
}

struct RepSetForgeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepSetForgeActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.state.currentExerciseName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Text("SET \(context.state.setIndex)/\(context.state.setTotal)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.attributes.startedAt, style: .timer)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Text("\(Int(context.state.volumeKg)) KG")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityPhaseView(state: context.state, compact: false)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(context.state.sessionSetCount), total: Double(max(context.state.sessionSetTotal, 1)))
                        .tint(.green)
                }
            } compactLeading: {
                Image(systemName: phaseIcon(context.state))
                    .foregroundStyle(phaseColor(context.state))
            } compactTrailing: {
                LiveActivityPhaseView(state: context.state, compact: true)
            } minimal: {
                Image(systemName: phaseIcon(context.state))
                    .foregroundStyle(phaseColor(context.state))
            }
        }
    }

    private func phaseIcon(_ state: RepSetForgeActivityAttributes.ContentState) -> String {
        switch state.phase {
        case .working: "dumbbell.fill"
        case .resting: "timer"
        }
    }

    private func phaseColor(_ state: RepSetForgeActivityAttributes.ContentState) -> Color {
        switch state.phase {
        case .working: .green
        case .resting: .orange
        }
    }
}

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<RepSetForgeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.attributes.workoutName.uppercased())
                Spacer()
                Text(context.attributes.startedAt, style: .timer)
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            LiveActivityPhaseView(state: context.state, compact: false)
            HStack {
                Text("\(context.state.currentExerciseName.uppercased()) · SET \(context.state.setIndex)/\(context.state.setTotal)")
                Spacer()
                Text("\(context.state.sessionSetCount)/\(context.state.sessionSetTotal)")
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            ProgressView(value: Double(context.state.sessionSetCount), total: Double(max(context.state.sessionSetTotal, 1)))
                .tint(.green)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.82))
        .activitySystemActionForegroundColor(.green)
    }
}

struct LiveActivityPhaseView: View {
    let state: RepSetForgeActivityAttributes.ContentState
    var compact: Bool

    var body: some View {
        switch state.phase {
        case .working:
            Text(compact ? "\(state.sessionSetCount)/\(state.sessionSetTotal)" : "WORKING")
                .font(.system(size: compact ? 12 : 18, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.green)
        case .resting(let end, _):
            Text(timerInterval: Date()...end, countsDown: true)
                .font(.system(size: compact ? 12 : 30, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.orange)
        }
    }
}
