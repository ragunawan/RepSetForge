import Foundation

enum PRKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case bestWeight
    case bestE1RM
    case bestVolume
    case repsAtWeight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bestWeight: return "Best weight"
        case .bestE1RM: return "Best e1RM"
        case .bestVolume: return "Best volume"
        case .repsAtWeight: return "Reps at weight"
        }
    }
}
