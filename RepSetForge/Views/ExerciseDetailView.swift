import SwiftUI
import SwiftData

/// dev spec §5, mockup frame 6. The 4W/3M/1Y range toggle isn't built — the
/// chart always shows full history, same simplification as the Exercise
/// Focus screen's in-context chart (they share `ExerciseHistoryService`).
struct ExerciseDetailView: View {
    let exercise: Exercise

    // Fetched unfiltered and matched in-memory — see ExerciseFocusView's
    // note on relationship-#Predicate risk in this environment.
    @Query private var allSetEntries: [SetEntry]
    @Query private var allPRRecords: [PRRecord]

    private var qualifyingSets: [SetEntry] {
        ExerciseHistoryService.qualifyingSets(exerciseID: exercise.id, in: allSetEntries)
    }

    private var stats: ExerciseHistoryService.BestStats {
        ExerciseHistoryService.bestStats(from: qualifyingSets)
    }

    private var trendPoints: [ExerciseTrendChart.Point] {
        ExerciseHistoryService.trendPoints(from: qualifyingSets)
    }

    private var prTimeline: [PRRecord] {
        allPRRecords
            .filter { $0.exercise?.id == exercise.id }
            .sorted { $0.achievedAt > $1.achievedAt }
    }

    private var recentSessions: [(date: Date, summary: String)] {
        let grouped = Dictionary(grouping: qualifyingSets) { $0.sessionExercise?.session?.id }
        let rows = grouped.values.compactMap { entries -> (Date, String)? in
            guard let date = entries.first?.sessionExercise?.session?.startedAt else { return nil }
            let summary = entries
                .sorted { $0.index < $1.index }
                .map { "\(Self.formatDecimal($0.weightKg ?? 0))×\($0.reps ?? 0)" }
                .joined(separator: " · ")
            return (date, summary)
        }
        return Array(rows.sorted { $0.0 > $1.0 }.prefix(5)).map { (date: $0.0, summary: $0.1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                statsCard
                if !trendPoints.isEmpty {
                    trendCard
                }
                if !prTimeline.isEmpty {
                    prTimelineCard
                }
                if !recentSessions.isEmpty {
                    recentSessionsCard
                }
                if qualifyingSets.isEmpty {
                    Text("Log this exercise to start tracking its history.")
                        .font(.system(size: 13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }
            .padding(14)
        }
        .background(RepSetForgeTheme.Colors.surface)
        .navigationTitle(exercise.name)
    }

    private var statsCard: some View {
        HStack {
            statColumn("Best kg", stats.bestWeight.map(Self.formatDecimal) ?? "—")
            Spacer()
            statColumn("e1RM", stats.bestE1RM.map(Self.formatDecimal) ?? "—", color: RepSetForgeTheme.Colors.signal)
            Spacer()
            statColumn("Best vol", stats.bestVolumeSet.map(Self.formatDecimal) ?? "—")
            Spacer()
            statColumn("Reps@max", stats.repsAtBestWeight.map(String.init) ?? "—")
        }
        .padding(12)
        .card()
    }

    private func statColumn(_ label: String, _ value: String, color: Color = RepSetForgeTheme.Colors.textPrimary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(16, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("E1RM TREND")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            ExerciseTrendChart(points: trendPoints)
            if let insight = trendInsight {
                Text(insight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            }
        }
        .padding(12)
        .card()
    }

    private var trendInsight: String? {
        guard trendPoints.count > 1, let first = trendPoints.first?.e1RM, let last = trendPoints.last?.e1RM else { return nil }
        let delta = last - first
        let sign = delta >= 0 ? "+" : ""
        return "e1RM \(delta >= 0 ? "up" : "down") \(sign)\(Self.formatDecimal(delta)) kg over \(trendPoints.count) sessions"
    }

    private var prTimelineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PR TIMELINE")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            ForEach(prTimeline.prefix(10)) { record in
                HStack {
                    Text(record.kind.displayName)
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Spacer()
                    Text(Self.formatDecimal(record.value))
                        .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.pr)
                    Text(Self.relativeDate(record.achievedAt))
                        .font(.system(size: 11))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }
        }
        .padding(12)
        .card()
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT SESSIONS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            ForEach(recentSessions, id: \.date) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.summary)
                        .font(RepSetForgeTheme.Typography.mono(13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Text(Self.relativeDate(row.date))
                        .font(.system(size: 11))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .card()
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private extension View {
    func card() -> some View {
        self
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
    }
}
