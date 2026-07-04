import Foundation
import SwiftData

/// Recomputes all derived progression — character level/XP/gold, muscle
/// levels/XP, completed-quest count, achievement unlocks, personal records,
/// skill XP, and equipment drops — from scratch by replaying completed-quest
/// history in chronological order.
///
/// Used whenever completed-quest history changes after the fact (undoing a
/// completion, or editing a completed quest's sets), instead of patching old
/// totals in place. Patching in place risks double-counting or leaving stale
/// XP/gold/achievements behind; rebuilding from the source of truth (the
/// completed quests themselves) never can.
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
        character.gold = 0
        character.totalPRCount = 0
        character.title = ProgressionService.title(for: character.level)
        let rpgClass = (try? context.fetch(FetchDescriptor<RPGEncounterState>()))?.first?.rpgClass ?? .knight

        for muscle in muscles {
            muscle.level = 1
            muscle.currentXP = 0
            muscle.totalXP = 0
        }

        for achievement in achievements {
            achievement.unlocked = false
            achievement.unlockedDate = nil
        }

        for record in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] {
            context.delete(record)
        }

        for skillProgress in (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? [] {
            skillProgress.currentXP = 0
            skillProgress.totalXP = 0
            skillProgress.unlocked = false
            skillProgress.unlockedDate = nil
        }

        let dropSources = Set([EquipmentDropService.questDropSource, EquipmentDropService.prDropSource])
        for owned in (try? context.fetch(FetchDescriptor<OwnedEquipment>())) ?? [] where dropSources.contains(owned.purchaseSource) {
            context.delete(owned)
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

            let newRecords = PersonalRecordService.evaluateRecords(for: quest.exercises, context: context, achievedDate: quest.completedDate ?? .now)
            let completedSetCount = quest.exercises.reduce(0) { $0 + $1.completedSets.count }
            character.gold += GoldService.totalGold(completedSetCount: completedSetCount, questXP: xp, newRecordCount: newRecords.count)

            SkillProgressionService.distributeSkillXP(
                exercises: quest.exercises,
                prExerciseNames: Set(newRecords.map(\.exerciseName)),
                context: context,
                at: quest.completedDate ?? .now
            )

            character.totalPRCount += newRecords.count
            EquipmentDropService.checkQuestMilestone(
                completedQuestCount: character.completedQuestCount,
                rpgClass: rpgClass,
                context: context,
                acquiredDate: quest.completedDate ?? .now
            )
            EquipmentDropService.checkPRMilestone(
                totalPRCount: character.totalPRCount,
                rpgClass: rpgClass,
                context: context,
                acquiredDate: quest.completedDate ?? .now
            )
        }

        // A skill's `equipped` flag is deliberately not reset above — it's the
        // player's own choice and should survive an unrelated quest's rebuild.
        // But if this specific skill no longer re-unlocked during replay (e.g.
        // the quest that unlocked it was edited/undone), clear the orphaned
        // flag so `equippedSkillIDs` doesn't report a locked skill as active.
        for skillProgress in (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? [] where skillProgress.equipped && !skillProgress.unlocked {
            skillProgress.equipped = false
        }

        return character
    }
}
