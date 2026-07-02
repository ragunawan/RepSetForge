import Foundation

/// The major training areas that level up independently as the player logs sets.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case cardio

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// SF Symbol placeholder standing in for hand-drawn pixel art icons.
    /// TODO: swap for custom pixel-art muscle group glyphs.
    var iconName: String {
        switch self {
        case .chest: return "shield.fill"
        case .back: return "square.stack.3d.up.fill"
        case .legs: return "figure.walk"
        case .shoulders: return "triangle.fill"
        case .arms: return "bolt.fill"
        case .core: return "circle.grid.cross.fill"
        case .cardio: return "heart.fill"
        }
    }
}
