import Foundation

enum PRRebuilder {
  static func rebuild(for exercise: Exercise, sets: [SetEntry]) -> [PRRecord] {
    sets.forEach { $0.isPR = false }

    let qualifyingSets = sets
      .filter { $0.type != .warmup && $0.completedAt != nil }
      .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }

    var records: [PRRecord] = []
    appendBestWeight(exercise: exercise, sets: qualifyingSets, records: &records)
    appendBestE1RM(exercise: exercise, sets: qualifyingSets, records: &records)
    appendBestVolume(exercise: exercise, sets: qualifyingSets, records: &records)
    appendRepsAtWeight(exercise: exercise, sets: qualifyingSets, records: &records)
    return records
  }

  private static func appendBestWeight(exercise: Exercise, sets: [SetEntry], records: inout [PRRecord]) {
    guard let winner = sets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
          let value = winner.weightKg,
          value > 0,
          let achievedAt = winner.completedAt
    else { return }

    winner.isPR = true
    records.append(PRRecord(exercise: exercise, kind: .bestWeight, value: value, set: winner, achievedAt: achievedAt))
  }

  private static func appendBestE1RM(exercise: Exercise, sets: [SetEntry], records: inout [PRRecord]) {
    guard let winner = sets.compactMap({ set -> (SetEntry, Decimal)? in
      guard let e1RM = set.estimatedOneRepMaxKg else { return nil }
      return (set, e1RM)
    }).max(by: { $0.1 < $1.1 }),
      let achievedAt = winner.0.completedAt
    else { return }

    winner.0.isPR = true
    records.append(PRRecord(exercise: exercise, kind: .bestE1RM, value: winner.1, set: winner.0, achievedAt: achievedAt))
  }

  private static func appendBestVolume(exercise: Exercise, sets: [SetEntry], records: inout [PRRecord]) {
    guard let winner = sets.compactMap({ set -> (SetEntry, Decimal)? in
      guard let volume = set.volumeKg else { return nil }
      return (set, volume)
    }).max(by: { $0.1 < $1.1 }),
      let achievedAt = winner.0.completedAt
    else { return }

    winner.0.isPR = true
    records.append(PRRecord(exercise: exercise, kind: .bestVolume, value: winner.1, set: winner.0, achievedAt: achievedAt))
  }

  private static func appendRepsAtWeight(exercise: Exercise, sets: [SetEntry], records: inout [PRRecord]) {
    let grouped = Dictionary(grouping: sets.filter { $0.weightKg != nil && $0.reps != nil }) { set in
      set.weightKg ?? 0
    }

    for (_, setsAtWeight) in grouped {
      guard let winner = setsAtWeight.max(by: { ($0.reps ?? 0) < ($1.reps ?? 0) }),
            let reps = winner.reps,
            reps > 0,
            let achievedAt = winner.completedAt
      else { continue }

      winner.isPR = true
      records.append(PRRecord(exercise: exercise, kind: .repsAtWeight, value: Decimal(reps), set: winner, achievedAt: achievedAt))
    }
  }
}
