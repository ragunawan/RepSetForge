import Foundation

/// Rebuilds PR state for one exercise from its full SetEntry history (§6
/// invalidation chain). Pure logic over value snapshots so it is unit-testable
/// and guaranteed independent of stored derived data — PRRecords and isPR
/// flags are outputs only, never inputs.
enum PRRebuilder {
    struct SetSnapshot: Equatable {
        var id: UUID
        var type: SetType
        var weightKg: Decimal?
        var reps: Int?
        var completedAt: Date?
    }

    struct RebuiltRecord: Equatable {
        var kind: PRKind
        var value: Decimal
        /// For .repsAtWeight, the weight the rep record applies to.
        var weightKg: Decimal?
        var setID: UUID
        var achievedAt: Date
    }

    struct Result: Equatable {
        var records: [RebuiltRecord]
        /// IDs of sets whose denormalized isPR flag must be true; all others false.
        var prSetIDs: Set<UUID>
    }

    /// Warmups never qualify for PRs; every other completed set with weight+reps does.
    static func qualifies(_ s: SetSnapshot) -> Bool {
        s.type != .warmup && s.completedAt != nil && s.weightKg != nil && (s.reps ?? 0) > 0
    }

    static func rebuild(history: [SetSnapshot]) -> Result {
        let sets = history.filter(qualifies).sorted { ($0.completedAt!) < ($1.completedAt!) }
        var bestWeight: RebuiltRecord?
        var bestE1RM: RebuiltRecord?
        var bestVolume: RebuiltRecord?
        var repsAtWeight: [Decimal: RebuiltRecord] = [:]
        var prSetIDs = Set<UUID>()

        for s in sets {
            guard let w = s.weightKg, let r = s.reps, let at = s.completedAt else { continue }
            var isPR = false

            if bestWeight == nil || w > bestWeight!.value {
                bestWeight = RebuiltRecord(kind: .bestWeight, value: w, weightKg: nil, setID: s.id, achievedAt: at)
                isPR = true
            }
            if let e1 = StrengthMath.epleyE1RM(weightKg: w, reps: r),
               bestE1RM == nil || e1 > bestE1RM!.value {
                bestE1RM = RebuiltRecord(kind: .bestE1RM, value: e1, weightKg: nil, setID: s.id, achievedAt: at)
                isPR = true
            }
            let vol = StrengthMath.volumeKg(weightKg: w, reps: r)
            if bestVolume == nil || vol > bestVolume!.value {
                bestVolume = RebuiltRecord(kind: .bestVolume, value: vol, weightKg: nil, setID: s.id, achievedAt: at)
                isPR = true
            }
            if let prior = repsAtWeight[w] {
                if Decimal(r) > prior.value {
                    repsAtWeight[w] = RebuiltRecord(kind: .repsAtWeight, value: Decimal(r), weightKg: w, setID: s.id, achievedAt: at)
                    isPR = true
                }
            } else {
                repsAtWeight[w] = RebuiltRecord(kind: .repsAtWeight, value: Decimal(r), weightKg: w, setID: s.id, achievedAt: at)
            }

            if isPR { prSetIDs.insert(s.id) }
        }

        var records: [RebuiltRecord] = []
        if let r = bestWeight { records.append(r) }
        if let r = bestE1RM { records.append(r) }
        if let r = bestVolume { records.append(r) }
        records.append(contentsOf: repsAtWeight.values.sorted { $0.weightKg! < $1.weightKg! })
        return Result(records: records, prSetIDs: prSetIDs)
    }
}
