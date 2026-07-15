import Foundation

enum WorkoutSessionStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case completed

    var id: String { rawValue }
}
