import Foundation

struct LadderLevel: Identifiable, Equatable {
  var id: String { "\(weightKg)-\(reps)" }
  let weightKg: Decimal
  let reps: Int
  let requiredSets: Int
  let completedAt: Date?

  var isCompleted: Bool {
    completedAt != nil
  }

  var estimatedOneRepMaxKg: Decimal {
    StrengthMath.estimatedOneRepMax(weightKg: weightKg, reps: reps) ?? weightKg
  }
}

struct LadderState: Equatable {
  let rule: ProgressionRuleSnapshot
  let levels: [LadderLevel]
  let currentLevel: LadderLevel
}

struct ProgressionRuleSnapshot: Equatable {
  var repRangeLow: Int
  var repRangeHigh: Int
  var maxQualifyingRPE: Decimal
  var qualifyingSetsRequired: Int
  var incrementKg: Decimal

  init(
    repRangeLow: Int = 8,
    repRangeHigh: Int = 12,
    maxQualifyingRPE: Decimal = 9,
    qualifyingSetsRequired: Int = 2,
    incrementKg: Decimal = 2.5
  ) {
    self.repRangeLow = repRangeLow
    self.repRangeHigh = max(repRangeLow, repRangeHigh)
    self.maxQualifyingRPE = maxQualifyingRPE
    self.qualifyingSetsRequired = max(1, qualifyingSetsRequired)
    self.incrementKg = incrementKg
  }

  init(_ rule: ProgressionRule) {
    self.init(
      repRangeLow: rule.repRangeLow,
      repRangeHigh: rule.repRangeHigh,
      maxQualifyingRPE: rule.maxQualifyingRPE,
      qualifyingSetsRequired: rule.qualifyingSetsRequired,
      incrementKg: rule.incrementKg
    )
  }
}

enum LadderEngine {
  static func rebuild(rule: ProgressionRuleSnapshot, baseWeightKg: Decimal, sets: [SetEntry]) -> LadderState {
    let orderedSets = sets
      .filter { $0.type != .warmup && $0.completedAt != nil }
      .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

    var weight = baseWeightKg
    var completions: [String: Date] = [:]

    while true {
      var advanced = false
      for reps in rule.repRangeLow...rule.repRangeHigh {
        guard let completedAt = qualifyingCompletionDate(weightKg: weight, reps: reps, rule: rule, sets: orderedSets) else {
          return state(rule: rule, weightKg: weight, currentReps: reps, completions: completions)
        }
        completions[key(weightKg: weight, reps: reps)] = completedAt
        advanced = reps == rule.repRangeHigh
      }

      if advanced {
        weight += rule.incrementKg
      }
    }
  }

  static func rebuild(rule: ProgressionRuleSnapshot, baseWeightKg: Decimal, focusSets: [FocusSet]) -> LadderState {
    let setEntries = focusSets.map {
      SetEntry(
        id: $0.id,
        index: $0.index,
        type: $0.type,
        weightKg: $0.weightKg,
        reps: $0.reps,
        rpe: $0.rpe,
        completedAt: $0.completedAt,
        isPR: $0.isPR
      )
    }
    return rebuild(rule: rule, baseWeightKg: baseWeightKg, sets: setEntries)
  }

  private static func state(
    rule: ProgressionRuleSnapshot,
    weightKg: Decimal,
    currentReps: Int,
    completions: [String: Date]
  ) -> LadderState {
    var levels = (rule.repRangeLow...rule.repRangeHigh).map { reps in
      LadderLevel(
        weightKg: weightKg,
        reps: reps,
        requiredSets: rule.qualifyingSetsRequired,
        completedAt: completions[key(weightKg: weightKg, reps: reps)]
      )
    }
    let current = levels.first { !$0.isCompleted } ?? LadderLevel(
      weightKg: weightKg + rule.incrementKg,
      reps: rule.repRangeLow,
      requiredSets: rule.qualifyingSetsRequired,
      completedAt: nil
    )
    if current.weightKg != weightKg {
      levels.append(current)
    }
    return LadderState(rule: rule, levels: levels, currentLevel: currentReps == current.reps ? current : current)
  }

  private static func qualifyingCompletionDate(
    weightKg: Decimal,
    reps: Int,
    rule: ProgressionRuleSnapshot,
    sets: [SetEntry]
  ) -> Date? {
    let qualifyingSets = sets.filter {
      $0.weightKg == weightKg &&
      $0.reps == reps &&
      ($0.rpe ?? 0) <= rule.maxQualifyingRPE
    }
    let bySession = Dictionary(grouping: qualifyingSets) { set in
      set.sessionExercise?.session?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }
    return bySession.values
      .compactMap { sessionSets -> Date? in
        guard sessionSets.count >= rule.qualifyingSetsRequired else { return nil }
        return sessionSets.compactMap(\.completedAt).max()
      }
      .min()
  }

  private static func key(weightKg: Decimal, reps: Int) -> String {
    "\(weightKg)-\(reps)"
  }
}
