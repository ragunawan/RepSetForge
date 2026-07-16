import Foundation

/// Ghost inheritance (§3 behavior contract #1): an untouched, uncompleted set
/// displays inherited values as ghost text — from the row above, or from the
/// previous session's matching set when it is the first row. Completing a set
/// commits the resolved values as real.
enum GhostResolver {
    struct RowValues: Equatable {
        var weightKg: Decimal?
        var reps: Int?
        var rpe: Double?
    }

    struct Resolved: Equatable {
        var values: RowValues
        /// True when the value shown is inherited (render textTertiary).
        var isGhost: Bool
    }

    /// - Parameters:
    ///   - rows: the actual stored values per row (nil = untouched).
    ///   - touched: per-row: user has edited or completed the row.
    ///   - previous: previous session's values by row index (first-row seed).
    static func resolve(rows: [RowValues], touched: [Bool], previous: [RowValues]) -> [Resolved] {
        var out: [Resolved] = []
        for (i, row) in rows.enumerated() {
            if touched.indices.contains(i), touched[i] {
                out.append(Resolved(values: row, isGhost: false))
                continue
            }
            var v = row
            // Fill each missing field independently: row above's resolved value,
            // else previous-session value at this index.
            let above = out.indices.contains(i - 1) ? out[i - 1].values : nil
            let prev = previous.indices.contains(i) ? previous[i] : nil
            if v.weightKg == nil { v.weightKg = above?.weightKg ?? prev?.weightKg }
            if v.reps == nil { v.reps = above?.reps ?? prev?.reps }
            if v.rpe == nil { v.rpe = above?.rpe ?? prev?.rpe }
            let inheritedSomething = v != row
            out.append(Resolved(values: v, isGhost: inheritedSomething))
        }
        return out
    }
}
