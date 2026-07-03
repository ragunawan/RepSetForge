import Foundation
import SwiftData

/// Recomputes all derived progression — character level/XP, muscle levels/XP,
/// completed-quest count, achievement unlocks, and personal records — from
/// scratch by replaying completed-quest history in chronological order.
///
/// Used whenever completed-quest history changes after the fact (undoing a
/// completion, or editing a completed quest's sets), instead of patching old
/// totals in place. Patching in place risks double-counting or leaving stale
/// XP/achievements behind; rebuilding from the source of truth (the completed
/// quests themselves) never can.
enum ProgressionRebuildService {
    @discardableResult
    static func rebuild(context: ModelContext) -> PlayerCharacter? {
        guard let character = try? context.fetch(FetchDescriptor<PlayerCharacter>()).first else { return nil }
        let muscles = (try? context.fetch(FetchDescriptor<MuscleProgress>())) ?? []
        let achievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []

        character.level = 1
        character.currentXP = 0
        character.totalXP = 0
        character.completedQuestCount = 0
        character.title = ProgressionService.title(for: character.level)

        for muscle in muscles {
            muscle.level = 1
            muscle.currentXP = 0
            muscle.totalXP = 0
        }

        for achievement in achievements {
            achievement.unlocked = false
            achievement.unlockedDate = nil
        }

        let completedRaw = QuestStatus.completed.rawValue
        let completedPredicate = #Predicate<Quest> { $0.statusRaw == completedRaw }
        let completedQuests = ((try? context.fetch(FetchDescriptor(predicate: completedPredicate))) ?? [])
            .sorted { ($0.completedDate ?? .distantPast) < ($1.completedDate ?? .distantPast) }

        for quest in completedQuests {
            let xp = ProgressionService.questXP(exercises: quest.exercises)
            quest.totalXP = xp
            ProgressionService.distributeXP(questXP: xp, exercises: quest.exercises, to: character, and: muscles)
            character.completedQuestCount += 1
            AchievementService.checkAchievements(character: character, muscles: muscles, context: context, at: quest.completedDate ?? .now)
        }

        PersonalRecordService.rebuildAll(context: context)

        return character
    }
}
