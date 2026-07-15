import Foundation

enum SetType: String, Codable, CaseIterable, Identifiable {
    case warmup
    case working
    case drop
    case failure
    case bodyweight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working"
        case .drop: return "Drop"
        case .failure: return "Failure"
        case .bodyweight: return "Bodyweight"
        }
    }

    /// Subscript letter for the set-index badge (e.g. "W" renders as W₁ for the first warm-up set).
    /// Working and bodyweight sets are numbered plainly instead (dev spec §3).
    var badgeLetter: String? {
        switch self {
        case .warmup: return "W"
        case .drop: return "D"
        case .failure: return "F"
        case .working, .bodyweight: return nil
        }
    }

    /// Warm-up sets are excluded from volume & PR calculations (dev spec §3).
    var countsTowardVolumeAndPRs: Bool {
        self != .warmup
    }
}
