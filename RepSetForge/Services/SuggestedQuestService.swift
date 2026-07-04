import Foundation

/// Suggests resuming a recently repeated workout routine, generated purely
/// from completed-quest history — not a saved template, and not random.
enum SuggestedQuestService {
    struct Suggestion {
        let name: String
        let exerciseBlueprints: [QuestExerciseBlueprint]
        let lastCompletedDate: Date
        let timesRepeated: Int
    }

    /// Looks back over `lookbackDays` of completed quests and suggests
    /// resuming whichever repeated routine (same name done 2+ times in the
    /// window) has gone the longest without a repeat — i.e. the one "due
    /// again" soonest. Returns nil if history shows no repeating pattern yet
    /// (a single quest, or every quest under a different name).
    static func suggestedQuest(from quests: [Quest], lookbackDays: Int = 30, now: Date = .now) -> Suggestion? {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else { return nil }

        let recentCompleted = quests.filter { quest in
            guard quest.status == .completed, let date = quest.completedDate else { return false }
            return date >= cutoff
        }

        let grouped = Dictionary(grouping: recentCompleted, by: \.name)
        let repeatedGroups = grouped.filter { $0.value.count >= 2 }
        guard !repeatedGroups.isEmpty else { return nil }

        // Whichever repeated routine's most recent occurrence is the oldest
        // is the one that's gone longest without being repeated.
        var due: (name: String, quests: [Quest], mostRecent: Date)?
        for (name, group) in repeatedGroups {
            guard let mostRecent = group.compactMap(\.completedDate).max() else { continue }
            if due == nil || mostRecent < due!.mostRecent {
                due = (name, group, mostRecent)
            }
        }
        guard let due,
              let latestQuest = due.quests.max(by: { ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast) })
        else { return nil }

        return Suggestion(
            name: due.name,
            exerciseBlueprints: latestQuest.exercises.map(QuestTemplateService.blueprint(from:)),
            lastCompletedDate: due.mostRecent,
            timesRepeated: due.quests.count
        )
    }

    /// Builds a fresh active Quest from a suggestion, ready to start today.
    static func makeQuest(from suggestion: Suggestion, unit: WeightUnit = .pounds) -> Quest {
        QuestTemplateService.makeQuest(name: suggestion.name, exerciseBlueprints: suggestion.exerciseBlueprints, unit: unit)
    }
}
