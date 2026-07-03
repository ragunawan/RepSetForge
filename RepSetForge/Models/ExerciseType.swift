import Foundation

/// How a skill is logged and measured. Drives which fields ExerciseSet
/// logging shows (reps/weight, distance, duration) for a given Exercise.
enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case strength
    case bodyweight
    case assisted
    case distance
    case duration
    case cardio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .bodyweight: return "Bodyweight"
        case .assisted: return "Assisted"
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .cardio: return "Cardio"
        }
    }

    /// Weighted strength work: reps + added weight.
    var tracksReps: Bool { self == .strength || self == .bodyweight || self == .assisted }
    var tracksWeight: Bool { self == .strength || self == .assisted }
    /// Distance-based work (running, rowing, cycling): logged in miles.
    var tracksDistance: Bool { self == .distance || self == .cardio }
    /// Time-based work (planks, timed runs): logged in seconds.
    var tracksDuration: Bool { self == .duration || self == .cardio }
}
