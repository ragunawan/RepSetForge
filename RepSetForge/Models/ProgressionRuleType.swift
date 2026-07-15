import Foundation

/// Only `.ladder` (double progression) has an engine behind it in v1.0.
/// Additional methodologies — 5/3/1, percentage waves, RIR autoregulation —
/// are v1.1 (dev spec §9 build order item 11, TODO.md). Don't add cases
/// here until they have real logic; that's the whole point of this being
/// an enum instead of a bool.
enum ProgressionRuleType: String, Codable, CaseIterable, Identifiable {
    case ladder

    var id: String { rawValue }
}
