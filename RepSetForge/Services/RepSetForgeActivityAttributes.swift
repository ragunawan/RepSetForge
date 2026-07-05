import ActivityKit
import Foundation

/// Shared between the phone app (which starts/updates/ends the activity)
/// and the widget extension (which renders it) — the same "one file, two
/// targets" pattern as the `@Model` classes shared with the widget's
/// timeline provider.
struct RepSetForgeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completedSetCount: Int
        var totalSetCount: Int
        /// When set, the Live Activity shows a native countdown via
        /// `Text(timerInterval:countsDown:)` — the system ticks this itself,
        /// so the app never needs to push a per-second update while resting.
        var restEndDate: Date?
    }

    var questName: String
}
