import SwiftUI

/// Bottom rest-timer pill (dev spec §4). Wall-clock driven via the shared
/// `RestTimerManager`; `now` is supplied by the caller's `TimelineView` so
/// this view doesn't need its own ticking mechanism.
struct RestTimerPill: View {
    let restTimer: RestTimerManager
    let now: Date

    private var remaining: TimeInterval { restTimer.remaining(now: now) }
    private var isOvertime: Bool { remaining < 0 }

    var body: some View {
        HStack(spacing: 10) {
            Text(isOvertime ? "+\(Self.format(-remaining))" : Self.format(remaining))
                .font(RepSetForgeTheme.Typography.mono(15, weight: .bold))
                .foregroundStyle(isOvertime ? RepSetForgeTheme.Colors.warn : RepSetForgeTheme.Colors.signal)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(RepSetForgeTheme.Colors.surfaceInput)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isOvertime ? RepSetForgeTheme.Colors.warn : RepSetForgeTheme.Colors.signal)
                            .frame(width: geometry.size.width * progress)
                    }
            }
            .frame(height: 5)

            Button("+30s") { restTimer.extend(by: 30, now: now) }
                .font(RepSetForgeTheme.Typography.mono(11, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RepSetForgeTheme.Colors.surfaceInput, in: Capsule())

            Button("Skip") { restTimer.skip(now: now) }
                .font(RepSetForgeTheme.Typography.mono(12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RepSetForgeTheme.Colors.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
    }

    private var progress: Double {
        guard let total = restTimer.restDurationTotal, total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    private static func format(_ interval: TimeInterval) -> String {
        let clamped = max(0, interval)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
