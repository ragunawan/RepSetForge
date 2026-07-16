import Foundation

enum ExerciseDeduplicator {
  static func canonicalNameKey(for name: String) -> String {
    name
      .lowercased()
      .unicodeScalars
      .filter { CharacterSet.alphanumerics.union(.whitespaces).contains($0) }
      .map(String.init)
      .joined()
      .split(separator: " ")
      .joined(separator: " ")
  }

  static func similarExercises(to name: String, existing: [Exercise]) -> [Exercise] {
    let candidate = canonicalNameKey(for: name)
    let candidateTokens = Set(candidate.split(separator: " ").map(String.init))

    return existing.filter { exercise in
      let existingKey = exercise.canonicalNameKey
      if levenshtein(candidate, existingKey) <= 2 {
        return true
      }

      let existingTokens = Set(existingKey.split(separator: " ").map(String.init))
      guard !candidateTokens.isEmpty, !existingTokens.isEmpty else {
        return false
      }
      return candidateTokens.isSubset(of: existingTokens) || existingTokens.isSubset(of: candidateTokens)
    }
  }

  private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    guard !a.isEmpty else { return b.count }
    guard !b.isEmpty else { return a.count }

    var previous = Array(0...b.count)
    var current = Array(repeating: 0, count: b.count + 1)

    for i in 1...a.count {
      current[0] = i
      for j in 1...b.count {
        let cost = a[i - 1] == b[j - 1] ? 0 : 1
        current[j] = min(
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost
        )
      }
      swap(&previous, &current)
    }

    return previous[b.count]
  }
}
