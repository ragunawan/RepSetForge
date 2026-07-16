import ActivityKit
import SwiftUI
import WidgetKit

/// §4 Live Activity surfaces (mockup frame 2e). Mono type, dark material.
/// All ticking is OS-driven (Text(timerInterval:), .timer style). One Skip
/// intent button while resting; none while working.
struct RepSetForgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Text("SET \(context.state.setIndex)/\(context.state.setTotal)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.startDate, style: .timer)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .frame(width: 64, alignment: .trailing)
                        Text("\(Int(context.state.volumeKg)) KG")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let start = context.state.restStart, let end = context.state.restEnd {
                        VStack(spacing: 2) {
                            Text(timerInterval: start...end, countsDown: true)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(RSF.signal)
                                .multilineTextAlignment(.center)
                            ProgressView(timerInterval: start...end, countsDown: false,
                                         label: {}, currentValueLabel: {})
                                .progressViewStyle(.linear)
                                .tint(RSF.signal)
                        }
                    } else {
                        SessionProgressBar(done: context.state.sessionSetCount,
                                           total: context.state.sessionSetTotal)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isResting {
                        HStack(spacing: 12) {
                            Button(intent: SkipRestIntent()) {
                                Text("SKIP").font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .buttonStyle(.bordered).tint(RSF.signal)
                            Button(intent: ExtendRestIntent()) {
                                Text("+30S").font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .buttonStyle(.bordered).tint(.secondary)
                        }
                    }
                }
            } compactLeading: {
                if context.state.isResting {
                    Image(systemName: "timer").foregroundStyle(RSF.signal)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(RSF.signal)
                }
            } compactTrailing: {
                // The one number that matters: rest countdown or elapsed.
                if let start = context.state.restStart, let end = context.state.restEnd {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(RSF.signal)
                        .frame(maxWidth: 44)
                } else {
                    Text(context.attributes.startDate, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                }
            } minimal: {
                if let start = context.state.restStart, let end = context.state.restEnd {
                    ProgressView(timerInterval: start...end, countsDown: true,
                                 label: {}, currentValueLabel: {})
                        .progressViewStyle(.circular)
                        .tint(RSF.signal)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(RSF.signal)
                }
            }
            .widgetURL(URL(string: "repsetforge://focus"))
        }
    }
}

/// Lock screen / banner (also CarPlay/StandBy source).
private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(context.attributes.workoutName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if let start = context.state.restStart, let end = context.state.restEnd {
                // Resting: countdown is the hero; exercise line demotes.
                HStack(alignment: .center) {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(RSF.signal)
                    Spacer()
                    Button(intent: SkipRestIntent()) {
                        Text("SKIP")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .buttonStyle(.bordered)
                    .tint(RSF.signal)
                }
                ProgressView(timerInterval: start...end, countsDown: false,
                             label: {}, currentValueLabel: {})
                    .progressViewStyle(.linear)
                    .tint(RSF.signal)
                Text("\(context.state.exerciseName.uppercased()) · SET \(context.state.setIndex)/\(context.state.setTotal)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("\(context.state.exerciseName.uppercased()) · SET \(context.state.setIndex)/\(context.state.setTotal)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                SessionProgressBar(done: context.state.sessionSetCount,
                                   total: context.state.sessionSetTotal)
            }
        }
        .padding(14)
    }
}

private struct SessionProgressBar: View {
    let done: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(RSF.signal)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0)
            }
        }
        .frame(height: 4)
    }
}

/// Widget-local color constants (extension can't depend on the app's
/// DesignTokens target file; values mirror repsetforge-tokens.json dark).
private enum RSF {
    static let signal = Color(red: 48 / 255, green: 229 / 255, blue: 133 / 255)
}
