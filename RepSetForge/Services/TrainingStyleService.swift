import Foundation

/// Derives a `TrainingStyle` badge from muscle-group XP distribution — a
/// character title/badge that reflects *how* someone trains, on top of the
/// level-gated title from `ProgressionService.title(for:)`.
enum TrainingStyleService {
    /// Minimum share of total muscle XP a single group must hold to be
    /// considered "dominant." Below this, training reads as balanced.
    static let dominanceThreshold = 0.35

    static func style(for muscles: [MuscleProgress]) -> TrainingStyle {
        let totalXP = muscles.reduce(0) { $0 + $1.totalXP }
        guard totalXP > 0, let strongest = muscles.max(by: { $0.totalXP < $1.totalXP }) else {
            return .freshRecruit
        }

        let share = Double(strongest.totalXP) / Double(totalXP)
        guard share >= dominanceThreshold else { return .allRounder }

        switch strongest.muscleGroup {
        case .chest: return .brawler
        case .back: return .anchor
        case .legs: return .powerhouse
        case .shoulders: return .titan
        case .arms: return .grappler
        case .core: return .ironclad
        case .cardio: return .marathoner
        }
    }
}
