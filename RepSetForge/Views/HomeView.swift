import SwiftUI
import SwiftData

/// dev spec §5 "Home (v1.7 — four modules)" / mockup frame 1. Each module
/// swaps from placeholder to live individually as its data arrives — the
/// screen never reorganizes, it fills in (dev spec §5 "First-run placeholder
/// modules"). Recommended-next is always a placeholder for now since
/// routines don't exist yet (TODO.md build-order step 6), and the Body
/// module shows the latest entry + delta rather than the full dual-axis
/// weight/body-fat chart with W/M/Y range paging.
struct HomeView: View {
    let activeSession: WorkoutSession?
    let onResume: (WorkoutSession) -> Void

    // Fetched unfiltered and matched in-memory — see ExerciseFocusView's
    // note on relationship-#Predicate risk in this environment.
    @Query private var allSessions: [WorkoutSession]
    @Query private var allPRRecords: [PRRecord]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]

    @State private var isPresentingLogWeight = false

    private var completedSessions: [WorkoutSession] {
        allSessions.filter { $0.status == .completed }
    }

    private var weeklySummary: HomeStatsService.WeeklySummary {
        HomeStatsService.weeklySummary(completedSessions: completedSessions, prRecords: allPRRecords)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let activeSession {
                        resumeBanner(activeSession)
                    }
                    recommendedNextPlaceholder
                    weekStripCard
                    bodyModuleCard
                }
                .padding(14)
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Home")
        }
        .sheet(isPresented: $isPresentingLogWeight) {
            LogBodyMetricSheet()
        }
    }

    // MARK: - Resume banner

    private func resumeBanner(_ session: WorkoutSession) -> some View {
        Button {
            onResume(session)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUT IN PROGRESS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.signal)
                    Text(session.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Text(elapsedSummary(session))
                        .font(RepSetForgeTheme.Typography.mono(12))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }
                Spacer()
                Text("Resume ▸")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RepSetForgeTheme.Colors.signalDim, in: Capsule())
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
            }
            .padding(12)
            .card(borderColor: RepSetForgeTheme.Colors.signal)
        }
        .buttonStyle(.plain)
    }

    private func elapsedSummary(_ session: WorkoutSession) -> String {
        let sets = session.sessionExercises.flatMap(\.setEntries).filter { $0.completedAt != nil }.count
        let minutes = max(0, Int(Date.now.timeIntervalSince(session.startedAt) / 60))
        return "\(minutes)m · \(sets) sets done"
    }

    // MARK: - Recommended next (always a placeholder — no routines yet)

    private var recommendedNextPlaceholder: some View {
        placeholderCard(
            title: "RECOMMENDED NEXT",
            message: "Build a routine to get session recommendations"
        )
    }

    // MARK: - Week strip

    private var weekStripCard: some View {
        Group {
            if completedSessions.isEmpty {
                placeholderCard(title: "THIS WEEK", message: "Your weekly summary appears after your first workout")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("THIS WEEK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                        Spacer()
                        if weeklySummary.streakWeeks > 0 {
                            Text("\(weeklySummary.streakWeeks) wk streak")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(RepSetForgeTheme.Colors.signal)
                        }
                    }
                    HStack {
                        statColumn("Sessions", "\(weeklySummary.sessionCount)")
                        Spacer()
                        statColumn("Volume", Self.formatDecimal(weeklySummary.volumeKg))
                        Spacer()
                        statColumn("Sets", "\(weeklySummary.setCount)")
                        Spacer()
                        statColumn("PRs", "\(weeklySummary.prCount)", color: RepSetForgeTheme.Colors.pr)
                    }
                    sparkline
                }
                .padding(12)
                .card()
            }
        }
    }

    private var sparkline: some View {
        let values = weeklySummary.weeklyVolumeSparkline
        let maxValue = values.max() ?? 0
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == values.count - 1 ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.surfaceInput)
                    .frame(height: barHeight(for: value, max: maxValue))
            }
        }
        .frame(height: 26, alignment: .bottom)
    }

    private func barHeight(for value: Decimal, max maxValue: Decimal) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        let fraction = NSDecimalNumber(decimal: value / maxValue).doubleValue
        return max(4, CGFloat(fraction) * 26)
    }

    // MARK: - Body module

    private var bodyModuleCard: some View {
        Group {
            if let latest = bodyMetrics.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("BODY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                        Spacer()
                        Button("Log weight") { isPresentingLogWeight = true }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RepSetForgeTheme.Colors.signal)
                    }
                    HStack(spacing: 16) {
                        if let weight = latest.bodyweightKg {
                            bodyStat("WEIGHT", "\(Self.formatDecimal(weight)) kg", delta: weightDelta)
                        }
                        if let bodyFat = latest.bodyFatPct {
                            bodyStat("BODY FAT", "\(Self.formatDecimal(bodyFat))%", delta: nil)
                        }
                    }
                }
                .padding(12)
                .card()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BODY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    Text("Log a bodyweight to start tracking")
                        .font(.system(size: 13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    Button("+ Log weight") { isPresentingLogWeight = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.signal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .dashedCard()
            }
        }
    }

    private var weightDelta: Decimal? {
        guard bodyMetrics.count > 1,
              let latest = bodyMetrics.first?.bodyweightKg,
              let previous = bodyMetrics.dropFirst().first?.bodyweightKg else { return nil }
        return latest - previous
    }

    private func bodyStat(_ label: String, _ value: String, delta: Decimal?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            HStack(spacing: 4) {
                Text(value)
                    .font(RepSetForgeTheme.Typography.mono(14, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                if let delta {
                    Text("(\(delta >= 0 ? "+" : "")\(Self.formatDecimal(delta)))")
                        .font(RepSetForgeTheme.Typography.mono(10))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Shared pieces

    private func statColumn(_ label: String, _ value: String, color: Color = RepSetForgeTheme.Colors.textPrimary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(15, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
    }

    private func placeholderCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .dashedCard()
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

private extension View {
    func card(borderColor: Color = RepSetForgeTheme.Colors.hairline) -> some View {
        self
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(borderColor, lineWidth: 1))
    }

    /// Placeholder-module styling: dashed hairline border, distinct from live cards (dev spec §5).
    func dashedCard() -> some View {
        self
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card)
                    .strokeBorder(RepSetForgeTheme.Colors.hairline, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
    }
}
