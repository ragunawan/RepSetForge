import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case core
    case quads
    case hamstrings
    case glutes
    case calves

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        }
    }
}
