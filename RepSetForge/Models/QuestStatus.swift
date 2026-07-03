import Foundation

/// Lifecycle of a workout ("quest").
enum QuestStatus: String, Codable, CaseIterable {
    case planned
    case active
    case completed

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}
