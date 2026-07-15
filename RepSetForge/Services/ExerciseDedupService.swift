import Foundation

/// Powers the "Similar exists" row in the create-exercise flow (dev spec §2,
/// mockup frame 3). The exercise database ships empty, so every name is
/// user-typed — this is what keeps "Row" / "Barbell Row" / "Rows" from
/// becoming three separate exercises.
enum ExerciseDedupService {
    struct Match {
        let exercise: Exercise
        let distance: Int
    }

    static let maxLevenshteinDistance = 2

    /// Existing exercises whose canonical name is "similar enough" to `name`:
    /// either a Levenshtein distance ≤ 2, or a token-subset match (every word
    /// in the shorter name appears in the longer one — catches "Row" vs.
    /// "Cable Row (Seated)"). Excludes exact canonical matches.
    static func similarExercises(to name: String, in candidates: [Exercise]) -> [Match] {
        let key = Exercise.canonicalKey(for: name)
        guard !key.isEmpty else { return [] }

        var matches: [Match] = []
        for candidate in candidates {
            let candidateKey = candidate.canonicalNameKey
            if candidateKey == key { continue }

            if isTokenSubset(key, candidateKey) {
                matches.append(Match(exercise: candidate, distance: 0))
                continue
            }

            let distance = levenshteinDistance(key, candidateKey)
            if distance <= maxLevenshteinDistance {
                matches.append(Match(exercise: candidate, distance: distance))
            }
        }
        return matches.sorted { $0.distance < $1.distance }
    }

    /// True when every whole word of the shorter key appears among the longer key's words.
    static func isTokenSubset(_ a: String, _ b: String) -> Bool {
        let tokensA = Set(a.split(separator: " "))
        let tokensB = Set(b.split(separator: " "))
        guard !tokensA.isEmpty, !tokensB.isEmpty else { return false }
        let (shorter, longer) = tokensA.count <= tokensB.count ? (tokensA, tokensB) : (tokensB, tokensA)
        return shorter.isSubset(of: longer)
    }

    static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previousRow = Array(0...b.count)
        var currentRow = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            currentRow[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            previousRow = currentRow
        }
        return previousRow[b.count]
    }
}
