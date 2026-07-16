import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct SkipRestIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Skip Rest"

  func perform() async throws -> some IntentResult {
    for activity in Activity<RepSetForgeActivityAttributes>.activities {
      var state = activity.content.state
      state.restPhase = .working
      await activity.update(ActivityContent(state: state, staleDate: nil))
    }
    return .result()
  }
}

struct ExtendRestIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Add 30 Seconds"

  func perform() async throws -> some IntentResult {
    for activity in Activity<RepSetForgeActivityAttributes>.activities {
      var state = activity.content.state
      if case let .resting(end, total) = state.restPhase {
        state.restPhase = .resting(end: end.addingTimeInterval(30), total: total + 30)
        await activity.update(ActivityContent(state: state, staleDate: nil))
      }
    }
    return .result()
  }
}

struct RepSetForgeLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RepSetForgeActivityAttributes.self) { context in
      LockScreenActivityView(context: context)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(DesignTokens.ColorToken.signal)
        .widgetURL(URL(string: "repsetforge://focus"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.step1) {
            Text(context.state.currentExerciseName.uppercased())
              .lineLimit(1)
            Text("SET \(context.state.setIndex)/\(context.state.setTotal)")
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: DesignTokens.Spacing.step1) {
            Text(context.attributes.startedAt, style: .timer)
              .forgeNumeric()
            Text("\(format(context.state.volumeKg)) KG")
              .forgeNumeric()
              .foregroundStyle(DesignTokens.ColorToken.textSecondary)
          }
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
        }
        DynamicIslandExpandedRegion(.center) {
          RestOrProgressView(context: context, compact: false)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if context.state.isResting {
            HStack {
              Button(intent: SkipRestIntent()) {
                Text("SKIP")
              }
              Spacer()
              Button(intent: ExtendRestIntent()) {
                Text("+30S")
              }
            }
            .forgeTextStyle(DesignTokens.Typography.eyebrow)
          }
        }
      } compactLeading: {
        RestGlyphView(isResting: context.state.isResting)
      } compactTrailing: {
        if case let .resting(end, _) = context.state.restPhase {
          Text(timerInterval: Date()...end, countsDown: true)
            .forgeNumeric()
            .foregroundStyle(DesignTokens.ColorToken.signal)
        } else {
          Text(context.attributes.startedAt, style: .timer)
            .forgeNumeric()
        }
      } minimal: {
        RestGlyphView(isResting: context.state.isResting)
      }
      .widgetURL(URL(string: "repsetforge://focus"))
    }
  }
}

private struct LockScreenActivityView: View {
  let context: ActivityViewContext<RepSetForgeActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.step3) {
      HStack {
        Text("\(context.attributes.workoutName.uppercased()) · ")
        Text(context.attributes.startedAt, style: .timer)
          .forgeNumeric()
        Spacer()
        if context.state.isResting {
          Button(intent: SkipRestIntent()) {
            Text("SKIP")
          }
          .forgeTextStyle(DesignTokens.Typography.eyebrow)
        }
      }
      .forgeTextStyle(DesignTokens.Typography.eyebrow)
      .foregroundStyle(DesignTokens.ColorToken.textSecondary)

      if case let .resting(end, total) = context.state.restPhase {
        Text(timerInterval: Date()...end, countsDown: true)
          .forgeTextStyle(DesignTokens.Typography.largeTitle)
          .forgeNumeric()
          .foregroundStyle(DesignTokens.ColorToken.signal)
        ProgressView(timerInterval: Date().addingTimeInterval(-max(1, total))...end, countsDown: false)
          .tint(DesignTokens.ColorToken.signal)
      } else {
        Text("\(context.state.currentExerciseName.uppercased()) · SET \(context.state.setIndex)/\(context.state.setTotal)")
          .forgeTextStyle(DesignTokens.Typography.heading)
          .lineLimit(1)
        ProgressView(value: Double(context.state.sessionSetCount), total: Double(max(1, context.state.sessionSetTotal)))
          .tint(DesignTokens.ColorToken.signal)
      }
    }
    .padding(DesignTokens.Spacing.step4)
    .foregroundStyle(DesignTokens.ColorToken.textPrimary)
  }
}

private struct RestOrProgressView: View {
  let context: ActivityViewContext<RepSetForgeActivityAttributes>
  let compact: Bool

  var body: some View {
    if case let .resting(end, _) = context.state.restPhase {
      Text(timerInterval: Date()...end, countsDown: true)
        .forgeTextStyle(compact ? DesignTokens.Typography.numericRow : DesignTokens.Typography.numericLarge)
        .forgeNumeric()
        .foregroundStyle(DesignTokens.ColorToken.signal)
    } else {
      ProgressView(value: Double(context.state.sessionSetCount), total: Double(max(1, context.state.sessionSetTotal)))
        .tint(DesignTokens.ColorToken.signal)
    }
  }
}

private struct RestGlyphView: View {
  let isResting: Bool

  var body: some View {
    Text(isResting ? "◷" : "◆")
      .forgeTextStyle(DesignTokens.Typography.numericRow)
      .foregroundStyle(isResting ? DesignTokens.ColorToken.signal : DesignTokens.ColorToken.textPrimary)
  }
}

private extension RepSetForgeActivityAttributes.ContentState {
  var isResting: Bool {
    if case .resting = restPhase { return true }
    return false
  }
}

private func format(_ value: Decimal) -> String {
  let number = NSDecimalNumber(decimal: value)
  return number.doubleValue.rounded(.towardZero) == number.doubleValue
    ? String(format: "%.0f", number.doubleValue)
    : String(format: "%.1f", number.doubleValue)
}
