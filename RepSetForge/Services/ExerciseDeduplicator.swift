import Foundation

/// Canonical-name dedup (§2): on custom-exercise creation, fuzzy-match the new
/// canonical key against existing keys — Levenshtein ≤ 2 OR token subset —
/// and surface a "Similar exists" row before allowing create.
enum ExerciseDeduplicator {
    static func similarKeys(to name: String, existingKeys: [String]) -> [String] {
        let candidate = StrengthMath.canonicalNameKey(name)
        guard !candidate.isEmpty else { return [] }
        return existingKeys.filter { isSimilar(candidate, $0) }
    }

    static func isSimilar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if levenshtein(a, b) <= 2 { return true }
        let ta = Set(a.split(separator: " "))
        let tb = Set(b.split(separator: " "))
        guard !ta.isEmpty, !tb.isEmpty else { return false }
        return ta.isSubset(of: tb) || tb.isSubset(of: ta)
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[t.count]
    }
}
