import Foundation

/// Double-progression ladder engine (§3 progression panel). Pure: the entire
/// ladder state is a function of (rule, starting weight, SetEntry history
/// grouped by session) — never stored authoritatively, so historical edits
/// regenerate it exactly (§6 invalidation chain step 2). The coaching prompt
/// always targets `currentLevel` — one source of truth.
enum LadderEngine {
    struct Rule: Equatable {
        var repRangeLow: Int
        var repRangeHigh: Int
        var maxQualifyingRPE: Double
        var qualifyingSetsRequired: Int
        var incrementKg: Decimal
    }

    struct SetFact: Equatable {
        var weightKg: Decimal
        var reps: Int
        var rpe: Double?
        var type: SetType
    }

    struct SessionFacts: Equatable {
        var date: Date
        var sets: [SetFact]
    }

    struct Level: Equatable {
        var weightKg: Decimal
        var reps: Int
        /// Session date that completed this level, nil if not yet completed.
        var completedOn: Date?
        var isLevelUp: Bool  // first level after a weight jump
        var e1RM: Decimal? { StrengthMath.epleyE1RM(weightKg: weightKg, reps: reps) }
    }

    struct State: Equatable {
        var levels: [Level]
        /// Index into `levels` of the current (first incomplete) level.
        var currentIndex: Int
        var current: Level { levels[currentIndex] }
    }

    /// One weight's rung sequence: every rep from low to high.
    static func rungs(weightKg: Decimal, rule: Rule, levelUp: Bool) -> [Level] {
        (rule.repRangeLow...rule.repRangeHigh).enumerated().map { i, r in
            Level(weightKg: weightKg, reps: r, completedOn: nil, isLevelUp: levelUp && i == 0)
        }
    }

    /// A set qualifies for a level when weight matches, reps meet or beat the
    /// level, RPE ≤ max (missing RPE counts — absence of strain data never
    /// blocks progression), and the set is a working-type set.
    static func qualifies(_ set: SetFact, level: Level, rule: Rule) -> Bool {
        guard set.type == .working || set.type == .failure else { return false }
        guard set.weightKg == level.weightKg, set.reps >= level.reps else { return false }
        if let rpe = set.rpe, rpe > rule.maxQualifyingRPE { return false }
        return true
    }

    /// Replay history chronologically from `startWeightKg`: within each
    /// session, the current level completes when ≥ qualifyingSetsRequired
    /// sets qualify; completing the top rung advances weight by incrementKg
    /// and regenerates the next rung block. Multiple levels can complete in
    /// one session (a big day skips rungs it out-performs).
    static func regenerate(rule: Rule, startWeightKg: Decimal,
                           history: [SessionFacts]) -> State {
        var weight = startWeightKg
        var levels = rungs(weightKg: weight, rule: rule, levelUp: false)
        var cursor = 0

        for session in history.sorted(by: { $0.date < $1.date }) {
            var advanced = true
            while advanced {
                advanced = false
                let level = levels[cursor]
                let hits = session.sets.filter { qualifies($0, level: level, rule: rule) }.count
                if hits >= rule.qualifyingSetsRequired {
                    levels[cursor].completedOn = session.date
                    if cursor == levels.count - 1 {
                        weight += rule.incrementKg
                        levels.append(contentsOf: rungs(weightKg: weight, rule: rule, levelUp: true))
                    }
                    cursor += 1
                    advanced = true
                }
            }
        }
        return State(levels: levels, currentIndex: cursor)
    }

    /// The coaching-prompt target IS the current level (single source of truth).
    static func promptTarget(rule: Rule, startWeightKg: Decimal,
                             history: [SessionFacts]) -> Level {
        regenerate(rule: rule, startWeightKg: startWeightKg, history: history).current
    }
}
