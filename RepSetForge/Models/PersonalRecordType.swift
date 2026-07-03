import Foundation

/// The kind of best-ever value a PersonalRecord tracks for a given exercise name.
enum PersonalRecordType: String, Codable, CaseIterable, Identifiable {
    case maxWeight
    case maxReps
    case bestVolume
    case longestDuration
    case fastestPace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .maxWeight: return "Max Weight"
        case .maxReps: return "Max Reps"
        case .bestVolume: return "Best Volume"
        case .longestDuration: return "Longest Duration"
        case .fastestPace: return "Fastest Pace"
        }
    }

    /// Fastest pace is minutes-per-mile, so a smaller number is the better record.
    var lowerIsBetter: Bool { self == .fastestPace }

    /// Formats `value` for display. `unit` only matters for the weight-based
    /// types (maxWeight, bestVolume); pass the record's own stored unit so
    /// historical entries always render in the unit they were actually set in.
    func formattedValue(_ value: Double, unit: WeightUnit = .pounds) -> String {
        switch self {
        case .maxWeight: return unit.formatted(value)
        case .maxReps: return "\(Int(value)) reps"
        case .bestVolume: return String(format: "%.0f %@", value, unit.abbreviation)
        case .longestDuration:
            let seconds = Int(value)
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        case .fastestPace: return String(format: "%.2f min/mi", value)
        }
    }
}
