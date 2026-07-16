import SwiftUI
import SwiftData
import Charts

/// §5 Progress: weekly volume rollups (computed live from SetEntry — derived
/// data, never stored), per-exercise e1RM trend, insight sentence.
struct ProgressTabView: View {
    @Query private var sessions: [WorkoutSession]

    private struct WeekBucket: Identifiable {
        var id: Date { weekStart }
        var weekStart: Date
        var volumeKg: Double
        var sets: Int
    }

    private var weeks: [WeekBucket] {
        let cal = Calendar.current
        let completedSets = sessions.filter { $0.status == .completed }
            .flatMap { $0.exercises ?? [] }
            .flatMap { $0.sets ?? [] }
            .filter { $0.completedAt != nil && $0.type != .warmup }
        let grouped = Dictionary(grouping: completedSets) { set -> Date in
            cal.dateInterval(of: .weekOfYear, for: set.completedAt!)?.start ?? set.completedAt!
        }
        return grouped.map { start, sets in
            WeekBucket(
                weekStart: start,
                volumeKg: sets.reduce(0.0) {
                    $0 + NSDecimalNumber(decimal: StrengthMath.volumeKg(weightKg: $1.weightKg, reps: $1.reps)).doubleValue
                },
                sets: sets.count)
        }
        .sorted { $0.weekStart < $1.weekStart }
        .suffix(12)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DT.Spacing.cardGap) {
                    if weeks.count < 2 {
                        lockedState
                    } else {
                        volumeCard
                        insightCard
                    }
                }
                .padding(.horizontal, DT.Spacing.s12 + 2)
                .padding(.vertical, DT.Spacing.s8)
            }
            .background(DT.Colors.surface)
            .navigationTitle("Progress")
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    private var lockedState: some View {
        VStack(spacing: DT.Spacing.s8) {
            Text("PROGRESS UNLOCKS AFTER 2 WEEKS OF TRAINING")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.textTertiary)
            Text("Keep logging — trends need history.")
                .font(DT.Type.secondary)
                .foregroundStyle(DT.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s8) {
            Text("WEEKLY VOLUME (KG)")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.textTertiary)
            Chart(weeks) { week in
                BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Volume", week.volumeKg))
                    .foregroundStyle(week.id == weeks.last?.id ? DT.Colors.signal : DT.Colors.surfaceInput)
            }
            .chartYAxis {
                AxisMarks { AxisValueLabel().font(DT.Type.eyebrow) }
            }
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .padding(DT.Spacing.cardPadding)
        .background(DT.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.hairline))
    }

    private var insightCard: some View {
        let insight: String = {
            guard weeks.count >= 2 else { return "" }
            let last = weeks[weeks.count - 1], prev = weeks[weeks.count - 2]
            guard prev.volumeKg > 0 else { return "First full week logged — baseline set." }
            let pct = Int(((last.volumeKg / prev.volumeKg) - 1) * 100)
            if pct >= 5 { return "Volume up \(pct)% vs. last week — trending up." }
            if pct <= -5 { return "Volume down \(abs(pct))% vs. last week — deload or missed sessions?" }
            return "Volume steady vs. last week (\(pct >= 0 ? "+" : "")\(pct)%)."
        }()
        return Text(insight)
            .font(DT.Type.secondary)
            .foregroundStyle(DT.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DT.Spacing.cardPadding)
            .background(DT.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.card).strokeBorder(DT.Colors.hairline))
    }
}
