import Foundation

/// A flavor badge reflecting *how* the player trains — which muscle group
/// dominates their XP — rather than just their character level.
enum TrainingStyle: String, CaseIterable, Identifiable {
    case brawler      // chest
    case anchor       // back
    case powerhouse   // legs
    case titan        // shoulders
    case grappler     // arms
    case ironclad     // core
    case marathoner   // cardio
    case allRounder   // no single muscle group dominates
    case freshRecruit // no muscle XP logged yet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brawler: return "The Brawler"
        case .anchor: return "The Anchor"
        case .powerhouse: return "The Powerhouse"
        case .titan: return "The Titan"
        case .grappler: return "The Grappler"
        case .ironclad: return "The Ironclad"
        case .marathoner: return "The Marathoner"
        case .allRounder: return "The All-Rounder"
        case .freshRecruit: return "Fresh Recruit"
        }
    }

    var detail: String {
        switch self {
        case .brawler: return "Your build leans Chest-dominant."
        case .anchor: return "Your build leans Back-dominant."
        case .powerhouse: return "Your build leans Legs-dominant."
        case .titan: return "Your build leans Shoulders-dominant."
        case .grappler: return "Your build leans Arms-dominant."
        case .ironclad: return "Your build leans Core-dominant."
        case .marathoner: return "Your build leans Cardio-dominant."
        case .allRounder: return "Your training is spread evenly across muscle groups."
        case .freshRecruit: return "Complete a quest to start shaping your training style."
        }
    }

    var iconName: String {
        switch self {
        case .brawler: return "shield.fill"
        case .anchor: return "square.stack.3d.up.fill"
        case .powerhouse: return "figure.walk"
        case .titan: return "triangle.fill"
        case .grappler: return "bolt.fill"
        case .ironclad: return "circle.grid.cross.fill"
        case .marathoner: return "heart.fill"
        case .allRounder: return "circle.hexagongrid.fill"
        case .freshRecruit: return "sparkles"
        }
    }
}
