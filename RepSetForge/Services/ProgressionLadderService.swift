import Foundation

/// Generates and evaluates the double-progression ladder for one exercise
/// (dev spec §3 "Progression panel", mockup frame 2c). Only `.ladder`
/// (double progression) exists — see `ProgressionRuleType`'s doc comment;
/// don't extend this for other methodologies.
enum ProgressionLadderService {
    struct Level: Identifiable {
        var id: String { "\(weightKg)x\(reps)" }
        let weightKg: Decimal
        let reps: Int
        let estimatedOneRepMax: Decimal
        /// The "fill the rep range, then add weight" step — the level past the top of the rep range.
        let isLevelUp: Bool
        var qualifyingSessionDates: [Date] = []

        var isComplete: Bool { !qualifyingSessionDates.isEmpty }
    }

    /// Builds the ladder for `rule` starting at `baseWeight`, evaluating
    /// completion against `historicalSets` (every set ever logged for this
    /// exercise, any session).
    static func ladder(
        rule: ProgressionRule,
        baseWeight: Decimal,
        historicalSets: [SetEntry]
    ) -> [Level] {
        guard rule.repRangeLow <= rule.repRangeHigh else { return [] }

        var levels: [Level] = []
        for reps in rule.repRangeLow...rule.repRangeHigh {
            let e1rm = estimatedOneRepMax(weight: baseWeight, reps: reps)
            var level = Level(weightKg: baseWeight, reps: reps, estimatedOneRepMax: e1rm, isLevelUp: false)
            level.qualifyingSessionDates = qualifyingSessions(for: level, rule: rule, sets: historicalSets)
            levels.append(level)
        }

        let levelUpWeight = baseWeight + rule.incrementKg
        levels.append(
            Level(
                weightKg: levelUpWeight,
                reps: rule.repRangeLow,
                estimatedOneRepMax: estimatedOneRepMax(weight: levelUpWeight, reps: rule.repRangeLow),
                isLevelUp: true
            )
        )

        return levels
    }

    /// The current level: the lowest rep count in the range that isn't yet
    /// complete, or the level-up entry once every rep level is complete.
    static func currentLevel(in levels: [Level]) -> Level? {
        levels.first { !$0.isComplete } ?? levels.last
    }

    /// Base weight for a fresh ladder: the most recent working-set weight
    /// logged for this exercise, or `nil` if it's never been logged.
    static func baseWeight(from historicalSets: [SetEntry]) -> Decimal? {
        historicalSets
            .filter { $0.type == .working && $0.completedAt != nil && $0.weightKg != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .first?
            .weightKg
    }

    /// Epley e1RM, matching `SetEntry.estimatedOneRepMax` but for a hypothetical
    /// weight/reps pair that may not have been logged yet — not capped at 12
    /// reps since the ladder needs the value even for out-of-validity-range
    /// projections (dev spec doesn't cap the ladder's own math, only the PR one).
    private static func estimatedOneRepMax(weight: Decimal, reps: Int) -> Decimal {
        weight * (1 + Decimal(reps) / 30)
    }

    /// Sessions in which this exact weight×(≥reps) was logged
    /// `qualifyingSetsRequired` or more times at RPE ≤ `maxQualifyingRPE`
    /// (missing RPE doesn't disqualify — spec doesn't require RPE to be on).
    private static func qualifyingSessions(
        for level: Level,
        rule: ProgressionRule,
        sets: [SetEntry]
    ) -> [Date] {
        let matching = sets.filter {
            $0.type.countsTowardVolumeAndPRs
                && $0.completedAt != nil
                && $0.weightKg == level.weightKg
                && ($0.reps ?? 0) >= level.reps
                && ($0.rpe.map { $0 <= rule.maxQualifyingRPE } ?? true)
        }
        let bySession = Dictionary(grouping: matching) { $0.sessionExercise?.session?.id }
        return bySession.values
            .filter { $0.count >= rule.qualifyingSetsRequired }
            .compactMap { $0.first?.sessionExercise?.session?.startedAt }
    }
}
