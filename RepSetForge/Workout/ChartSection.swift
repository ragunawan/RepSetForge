import SwiftUI
import Charts

/// §3.3 in-context chart: bars = per-session volume, line = e1RM trend,
/// dashed warning line = %1RM target. Collapses to a single row after the
/// first completed set on the page (state per-exercise-per-session).
/// History data feed arrives with Phase 6/7; until then renders placeholder
/// trend from the session itself. Lazy per page — never blocks set entry.
struct ChartSection: View {
    @Bindable var vm: WorkoutViewModel
    let pageIndex: Int
    let exercise: SessionExercise
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let expanded = vm.chartExpanded(pageIndex: pageIndex, exercise: exercise)
        Group {
            if expanded { expandedChart } else { collapsedRow }
        }
        .animation(reduceMotion ? DT.Motion.reducedMotionFade : DT.Motion.stateChange, value: expanded)
    }

    private var collapsedRow: some View {
        Button {
            vm.chartOpen[pageIndex] = true
        } label: {
            HStack {
                Text("CHART")
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(DT.Colors.textTertiary)
                Spacer()
                HStack(spacing: 4) {
                    Text("1RM \(oneRMText)")
                        .foregroundStyle(DT.Colors.textSecondary)
                    Text("· PR \(prText)")
                        .foregroundStyle(DT.Colors.pr)
                    Text("▾").foregroundStyle(DT.Colors.textSecondary)
                }
                .font(DT.Type.secondary)
                .monospacedDigit()
            }
            .padding(.horizontal, DT.Spacing.s16 + 2)
            .frame(minHeight: DT.Touch.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedChart: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s8) {
            HStack {
                chip("Weight × Reps", on: true)
                Spacer()
                chip("3M", on: false)
                chip("%1RM", on: false)
            }
            Chart {
                ForEach(Array(trend.enumerated()), id: \.offset) { i, v in
                    BarMark(x: .value("Session", i), y: .value("Volume", v.volume))
                        .foregroundStyle(DT.Colors.surfaceInput)
                    LineMark(x: .value("Session", i), y: .value("e1RM", v.e1rm))
                        .foregroundStyle(DT.Colors.signal)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                }
                if let target = pct75Target {
                    RuleMark(y: .value("75%", target))
                        .foregroundStyle(DT.Colors.warning)
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .annotation(position: .topLeading) {
                            Text("— 75% · \(target, specifier: "%.0f") kg")
                                .font(DT.Type.eyebrow)
                                .foregroundStyle(DT.Colors.warning)
                        }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 110)
            HStack(spacing: DT.Spacing.s8 - 2) {
                chip("1RM \(oneRMText) kg", on: false)
                Text("PR \(prText)")
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(DT.Colors.pr)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(DT.Colors.prDim)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(DT.Colors.pr))
            }
        }
        .padding(.horizontal, DT.Spacing.s12)
        .padding(.vertical, DT.Spacing.s8)
    }

    private func chip(_ label: String, on: Bool) -> some View {
        Text(label)
            .font(DT.Type.eyebrow)
            .foregroundStyle(on ? DT.Colors.signal : DT.Colors.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(on ? DT.Colors.signalDim : DT.Colors.surfaceInput)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(on ? DT.Colors.signal : DT.Colors.hairline))
            .monospacedDigit()
    }

    // Placeholder data (history feed = Phase 6/7)

    private struct TrendPoint { var volume: Double; var e1rm: Double }

    private var trend: [TrendPoint] {
        let sets = vm.orderedSets(exercise).filter { $0.completedAt != nil }
        guard !sets.isEmpty else {
            return (0..<8).map { TrendPoint(volume: Double(20 + $0 * 3), e1rm: Double(90 + $0 * 2)) }
        }
        return sets.map {
            TrendPoint(volume: NSDecimalNumber(decimal: StrengthMath.volumeKg(weightKg: $0.weightKg, reps: $0.reps)).doubleValue,
                       e1rm: $0.e1RM.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0)
        }
    }

    private var oneRMText: String {
        let best = vm.orderedSets(exercise).compactMap { $0.e1RM }.max()
        guard let best else { return "—" }
        return NSDecimalNumber(decimal: best).doubleValue.formatted(.number.precision(.fractionLength(0)))
    }

    private var prText: String {
        let done = vm.orderedSets(exercise).filter { $0.isPR }
        guard let top = done.last, let w = top.weightKg, let r = top.reps else { return "—" }
        return "\(NSDecimalNumber(decimal: w).doubleValue.formatted(.number.precision(.fractionLength(0...1))))×\(r)"
    }

    private var pct75Target: Double? {
        guard let best = vm.orderedSets(exercise).compactMap({ $0.e1RM }).max() else { return nil }
        return NSDecimalNumber(decimal: best).doubleValue * 0.75
    }
}
