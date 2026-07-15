import SwiftUI
import SwiftData

/// Post-workout summary (dev spec §5, mockup frame 4). PR callouts key off
/// `PRRecord.setEntry`'s session rather than a separate "PRs this session"
/// list, so no extra bookkeeping is needed at commit time. The
/// routine-update diff sheet and HealthKit "Saved to Health" row are still
/// TODO.md work (build-order step 5) — there's no routine or HealthKit
/// integration to hook into yet.
struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    // Fetched unfiltered and matched in-memory — see ExerciseFocusView's
    // note on relationship-#Predicate risk in this environment.
    @Query private var allSessions: [WorkoutSession]
    @Query private var allPRRecords: [PRRecord]

    private var completedSets: [SetEntry] {
        session.sessionExercises.flatMap(\.setEntries)
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
    }

    private var totalVolume: Decimal {
        completedSets.compactMap(\.volumeKg).reduce(0, +)
    }

    private var totalReps: Int {
        completedSets.compactMap(\.reps).reduce(0, +)
    }

    private var durationText: String {
        guard let endedAt = session.endedAt else { return "—" }
        let minutes = max(0, Int(endedAt.timeIntervalSince(session.startedAt) / 60))
        return "\(minutes) min"
    }

    private var prsThisSession: [PRRecord] {
        allPRRecords.filter { $0.setEntry?.sessionExercise?.session?.id == session.id }
    }

    /// dev spec §5: "deltas computed vs. most recent completed session
    /// sharing the same routineRef (fallback: same name)" — no routines
    /// exist yet, so this always falls back to matching by name.
    private var previousSession: WorkoutSession? {
        allSessions
            .filter { $0.id != session.id && $0.status == .completed && $0.name == session.name }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    private var muscleSetCounts: [(muscle: MuscleGroup, count: Int)] {
        var counts: [MuscleGroup: Int] = [:]
        for sessionExercise in session.sessionExercises {
            guard let exercise = sessionExercise.exercise else { continue }
            let qualifyingSets = sessionExercise.setEntries
                .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
                .count
            for muscle in exercise.muscleGroups {
                counts[muscle, default: 0] += qualifyingSets
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (muscle: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard
                    if !prsThisSession.isEmpty {
                        prCard
                    }
                    if let previousSession {
                        comparisonCard(previousSession)
                    }
                    if !muscleSetCounts.isEmpty {
                        musclesCard
                    }
                }
                .padding(14)
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Workout done")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Text("Today")
                .font(.system(size: 13))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)

            Rectangle()
                .fill(RepSetForgeTheme.Colors.hairline)
                .frame(height: 1)
                .padding(.vertical, 6)

            HStack {
                statColumn("Duration", durationText)
                Spacer()
                statColumn("Sets", "\(completedSets.count)")
                Spacer()
                statColumn("Reps", "\(totalReps)")
                Spacer()
                statColumn("Volume", Self.formatDecimal(totalVolume))
            }
        }
        .padding(12)
        .card()
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(18, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
    }

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(prsThisSession.count) Personal record\(prsThisSession.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.pr)
            ForEach(prsThisSession, id: \.id) { record in
                HStack {
                    Text(record.exercise?.name ?? "Exercise")
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Spacer()
                    Text("\(record.kind.displayName): \(Self.formatDecimal(record.value))")
                        .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.pr)
                }
            }
        }
        .padding(12)
        .background(RepSetForgeTheme.Colors.prDim, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(RepSetForgeTheme.Colors.pr, lineWidth: 1))
    }

    private func comparisonCard(_ previous: WorkoutSession) -> some View {
        let previousVolume = previous.sessionExercises.flatMap(\.setEntries)
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
            .compactMap(\.volumeKg)
            .reduce(Decimal(0), +)
        let delta: Decimal? = previousVolume > 0 ? (totalVolume - previousVolume) / previousVolume * 100 : nil

        return VStack(alignment: .leading, spacing: 6) {
            Text("vs. last \(session.name)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            HStack {
                Text("Volume")
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                Spacer()
                if let delta {
                    Text(Self.formatSignedPercent(delta))
                        .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                        .foregroundStyle(delta >= 0 ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.warn)
                } else {
                    Text("—").foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }
        }
        .padding(12)
        .card()
    }

    private var musclesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Muscles trained")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(muscleSetCounts, id: \.muscle) { entry in
                        Text("\(entry.muscle.displayName) \(entry.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RepSetForgeTheme.Colors.surfaceInput, in: Capsule())
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .card()
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func formatSignedPercent(_ value: Decimal) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(NSDecimalNumber(decimal: value).stringValue)%"
    }
}

private extension View {
    func card() -> some View {
        self
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.card).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
    }
}
