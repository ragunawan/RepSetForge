import Foundation

/// Autocomplete suggestions for the "Add Skill" name field, drawn from
/// previously logged exercise names — pure and stateless, no persisted
/// state of its own.
enum ExerciseNameSuggestionService {
    /// Returns up to `limit` distinct previously-logged names matching
    /// `query` (case-insensitive substring match), ranked prefix matches
    /// first, then by how often that name has been logged, then
    /// alphabetically. Names that exactly match the query (nothing left to
    /// autocomplete) are excluded. Empty query yields no suggestions.
    static func suggestions(matching query: String, exerciseNames: [String], limit: Int = 5) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        let lowercasedQuery = trimmedQuery.lowercased()

        var frequency: [String: Int] = [:]
        var displayName: [String: String] = [:]
        for name in exerciseNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            frequency[key, default: 0] += 1
            if displayName[key] == nil { displayName[key] = trimmed }
        }

        let matchingKeys = frequency.keys.filter { $0.contains(lowercasedQuery) && $0 != lowercasedQuery }

        return matchingKeys
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.hasPrefix(lowercasedQuery)
                let rhsPrefix = rhs.hasPrefix(lowercasedQuery)
                if lhsPrefix != rhsPrefix { return lhsPrefix }

                let lhsFrequency = frequency[lhs] ?? 0
                let rhsFrequency = frequency[rhs] ?? 0
                if lhsFrequency != rhsFrequency { return lhsFrequency > rhsFrequency }

                return lhs < rhs
            }
            .prefix(limit)
            .compactMap { displayName[$0] }
    }
}
