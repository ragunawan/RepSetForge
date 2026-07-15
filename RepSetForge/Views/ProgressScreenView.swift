import SwiftUI
import SwiftData

/// dev spec §5, mockup frame 8. Named `ProgressScreenView` rather than
/// `ProgressView` — the latter would shadow SwiftUI's own `ProgressView`,
/// which `ExerciseFocusView` already uses for its telemetry progress bar.
///
/// The muscle-distribution "target" is a hardcoded 12 sets/week (matching
/// the mockup's own example) since there's no Settings screen yet to make
/// it configurable (TODO.md build-order step 8). The per-exercise "trend
/// locked" card (e.g. "Log 3 more deadlift sessions") isn't built — it's a
/// narrower, exercise-specific insight distinct from these three cards.
struct ProgressScreenView: View {
    @Query private var allSessions: [WorkoutSession]
    @Query private var allPRRecords: [PRRecord]

    @State private var period: ProgressStatsService.Period = .threeMonths

    private static let targetSetsPerWeek: Double = 12

    private var completedSessions: [WorkoutSession] {
        allSessions.filter { $0.status == .completed }
    }

    private var summary: ProgressStatsService.Summary {
        ProgressStatsService.summary(period: period, completedSessions: completedSessions, prRecords: allPRRecords)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if completedSessions.isEmpty {
                        emptyState
                    } else {
                        volumeCard
                        frequencyCard
                        muscleDistributionCard
                    }
                }
                .padding(14)
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Range", selection: $period) {
                        ForEach(ProgressStatsService.Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
        }
    }

    private var emptyState: some View {
        Text("Log a few workouts to see your progress here")
            .font(.system(size: 13))
            .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }

    // MARK: - Weekly volume

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEKLY VOLUME")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            volumeSparkline
            if let insight = volumeInsight {
                Text(insight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            }
        }
        .padding(12)
        .card()
    }

    private var volumeSparkline: some View {
        let values = summary.weeklyVolumes
        let maxValue = values.max() ?? 0
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == values.count - 1 ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.surfaceInput)
                    .frame(height: barHeight(for: value, max: maxValue))
            }
        }
        .frame(height: 48, alignment: .bottom)
    }

    private func barHeight(for value: Decimal, max maxValue: Decimal) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        let fraction = NSDecimalNumber(decimal: value / maxValue).doubleValue
        return max(4, CGFloat(fraction) * 48)
    }

    private var volumeInsight: String? {
        guard let maxValue = summary.weeklyVolumes.max(), maxValue > 0,
              let lastValue = summary.weeklyVolumes.last, lastValue == maxValue else { return nil }
        return "Best volume week in this period — \(Self.formatDecimal(maxValue)) kg"
    }

    // MARK: - Frequency & consistency

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FREQUENCY & CONSISTENCY")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            kv("Avg sessions / week", String(format: "%.1f", summary.averageSessionsPerWeek))
            kv("Current streak", summary.streakWeeks > 0 ? "\(summary.streakWeeks) weeks" : "—", valueColor: RepSetForgeTheme.Colors.signal)
            kv("PRs this period", "\(summary.prCount)", valueColor: RepSetForgeTheme.Colors.pr)
        }
        .padding(12)
        .card()
    }

    private func kv(_ label: String, _ value: String, valueColor: Color = RepSetForgeTheme.Colors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Muscle distribution

    private var muscleDistributionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLE DISTRIBUTION · SETS/WK")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            if summary.muscleSetsPerWeek.isEmpty {
                Text("No sets logged in this period yet")
                    .font(.system(size: 12))
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            } else {
                ForEach(summary.muscleSetsPerWeek, id: \.muscle) { entry in
                    muscleRow(entry)
                }
                if let underTarget = summary.muscleSetsPerWeek.first(where: { $0.setsPerWeek < Self.targetSetsPerWeek }) {
                    Text("\(underTarget.muscle.displayName) below your \(Int(Self.targetSetsPerWeek))-set target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.warn)
                }
            }
        }
        .padding(12)
        .card()
    }

    private func muscleRow(_ entry: (muscle: MuscleGroup, setsPerWeek: Double)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.muscle.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                Spacer()
                Text(String(format: "%.0f", entry.setsPerWeek))
                    .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 3)
                    .fill(RepSetForgeTheme.Colors.surfaceInput)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.setsPerWeek < Self.targetSetsPerWeek ? RepSetForgeTheme.Colors.warn : RepSetForgeTheme.Colors.signal)
                            .frame(width: geometry.size.width * min(1, entry.setsPerWeek / Self.targetSetsPerWeek))
                    }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 3)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

private extension View {
    func card() -> some View {
        self
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
    }
}
