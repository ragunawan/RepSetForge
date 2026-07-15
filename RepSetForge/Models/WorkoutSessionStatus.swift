import Foundation

enum WorkoutSessionStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case active
    case completed

    var id: String { rawValue }
}
