import Foundation
import SwiftData

/// Backs the Settings screen's "Privacy & Data" section. RepSetForge is
/// local-only (see `CLAUDE.md`) — this service's only job is giving the
/// user a real, working way to erase that local data, not managing any
/// server-side account or consent state (there is none).
enum PrivacyDataService {
    /// Deletes every quest (and, via cascade, its exercises and sets), then
    /// rebuilds derived progression from the now-empty history — reusing
    /// `ProgressionRebuildService` rather than hand-resetting every field,
    /// so character/muscle levels, gold, achievements, and personal records
    /// all correctly return to baseline. Deliberately does *not* touch
    /// onboarding completion, class selection, or owned equipment/skills —
    /// those are standing preferences, not workout history, and resetting
    /// them isn't what "delete my data" implies.
    static func deleteAllWorkoutData(context: ModelContext) {
        let quests = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        for quest in quests {
            context.delete(quest)
        }
        ProgressionRebuildService.rebuild(context: context)
        try? context.save()
    }
}
