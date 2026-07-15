import SwiftUI
import Charts

/// Per-session e1RM trend for one exercise (dev spec §3 "In-context chart").
/// A simplified slice of the mockup's combo chart: the volume bars, %1RM
/// overlay, and date-range toggle are still TODO.md work — this renders the
/// e1RM line only, which is what the coaching prompt and PR chips key off.
struct ExerciseTrendChart: View {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let e1RM: Decimal
    }

    let points: [Point]

    var body: some View {
        Group {
            if points.isEmpty {
                Text("Log a few sessions to see your trend here.")
                    .font(RepSetForgeTheme.Typography.mono(11))
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Session", point.date),
                        y: .value("e1RM", NSDecimalNumber(decimal: point.e1RM).doubleValue)
                    )
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Session", point.date),
                        y: .value("e1RM", NSDecimalNumber(decimal: point.e1RM).doubleValue)
                    )
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 110)
            }
        }
    }
}
