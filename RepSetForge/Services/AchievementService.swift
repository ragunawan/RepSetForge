import Foundation
import SwiftData

/// Achievement definitions and unlock-condition checks.
enum AchievementService {
    struct Definition {
        let key: String
        let name: String
        let detail: String
        let iconName: String
    }

    /// Canonical list of every achievement in the game. Seeded once at first launch.
    static let definitions: [Definition] = [
        Definition(key: "first_quest", name: "First Quest", detail: "Complete your first quest.", iconName: "flag.checkered"),
        Definition(key: "ten_quests", name: "Quest Veteran", detail: "Complete 10 quests.", iconName: "flag.checkered.2.crossed"),
        Definition(key: "first_level_up", name: "Level Up!", detail: "Reach character level 2.", iconName: "arrow.up.circle.fill"),
        Definition(key: "level_10", name: "Dungeon Athlete", detail: "Reach character level 10.", iconName: "star.circle.fill"),
        Definition(key: "hundred_sets", name: "Set Machine", detail: "Log 100 completed sets.", iconName: "repeat.circle.fill"),
        Definition(key: "muscle_specialist", name: "Muscle Specialist", detail: "Level any muscle group to level 5.", iconName: "bolt.heart.fill"),
        Definition(key: "three_day_streak", name: "Getting Started", detail: "Complete quests on 3 consecutive days.", iconName: "calendar"),
        Definition(key: "seven_day_streak", name: "7-Day Streak", detail: "Complete quests on 7 consecutive days.", iconName: "calendar.badge.clock"),
        Definition(key: "thirty_day_streak", name: "Iron Will", detail: "Complete quests on 30 consecutive days.", iconName: "calendar.badge.exclamationmark"),
        Definition(key: "first_pr", name: "First PR", detail: "Set your first personal record.", iconName: "trophy.fill"),
        Definition(key: "volume_10k", name: "Volume Crusher", detail: "Lift 10,000 lb of total volume across all sets.", iconName: "scalemass.fill"),
        Definition(key: "balanced_trainer", name: "Balanced Trainer", detail: "Earn XP in every muscle group.", iconName: "figure.strengthtraining.traditional"),
        Definition(key: "ten_workout_days", name: "Creature of Habit", detail: "Complete quests on 10 different days.", iconName: "checkmark.calendar"),
    ]

    static func seedDefinitions() -> [Achievement] {
        definitions.map { Achievement(key: $0.key, name: $0.name, detail: $0.detail, iconName: $0.iconName) }
    }

    /// Evaluates every unlock condition against current progress and flips any
    /// newly-met achievements to unlocked, returning just the ones that changed.
    @discardableResult
    static func checkAchievements(
        character: PlayerCharacter,
        muscles: [MuscleProgress],
        context: ModelContext,
        at date: Date = .now
    ) -> [Achievement] {
        guard let achievements = try? context.fetch(FetchDescriptor<Achievement>()) else { return [] }
        let byKey = Dictionary(uniqueKeysWithValues: achievements.map { ($0.key, $0) })

        var newlyUnlocked: [Achievement] = []
        func unlock(_ key: String) {
            guard let achievement = byKey[key], !achievement.unlocked else { return }
            achievement.unlocked = true
            achievement.unlockedDate = date
            newlyUnlocked.append(achievement)
        }

        if character.completedQuestCount >= 1 { unlock("first_quest") }
        if character.completedQuestCount >= 10 { unlock("ten_quests") }
        if character.level >= 2 { unlock("first_level_up") }
        if character.level >= 10 { unlock("level_10") }
        if muscles.contains(where: { $0.level >= 5 }) { unlock("muscle_specialist") }
        if !muscles.isEmpty && muscles.allSatisfy({ $0.totalXP > 0 }) { unlock("balanced_trainer") }

        let completedSetPredicate = #Predicate<ExerciseSet> { $0.completed }
        let completedSets = (try? context.fetch(FetchDescriptor(predicate: completedSetPredicate))) ?? []
        if completedSets.count >= 100 {
            unlock("hundred_sets")
        }

        let totalVolume = completedSets.reduce(0.0) { $0 + Double($1.reps) * $1.weightUnit.convert($1.weight, to: .pounds) }
        if totalVolume >= 10_000 {
            unlock("volume_10k")
        }

        if (try? context.fetchCount(FetchDescriptor<PersonalRecord>())) ?? 0 >= 1 {
            unlock("first_pr")
        }

        let completedDays = completedQuestDays(context: context)
        if completedDays.count >= 10 {
            unlock("ten_workout_days")
        }
        if hasStreak(ofDays: 3, completedDays: completedDays) {
            unlock("three_day_streak")
        }
        if hasStreak(ofDays: 7, completedDays: completedDays) {
            unlock("seven_day_streak")
        }
        if hasStreak(ofDays: 30, completedDays: completedDays) {
            unlock("thirty_day_streak")
        }

        return newlyUnlocked
    }

    private static func completedQuestDays(context: ModelContext) -> Set<Date> {
        let completedQuestPredicate = #Predicate<Quest> { $0.completedDate != nil }
        guard let quests = try? context.fetch(FetchDescriptor(predicate: completedQuestPredicate)) else {
            return []
        }
        let calendar = Calendar.current
        return Set(quests.compactMap { quest -> Date? in
            guard let date = quest.completedDate else { return nil }
            return calendar.startOfDay(for: date)
        })
    }

    private static func hasStreak(ofDays length: Int, completedDays: Set<Date>) -> Bool {
        let calendar = Calendar.current
        guard let mostRecent = completedDays.max() else { return false }
        for offset in 0..<length {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: mostRecent),
                  completedDays.contains(day) else {
                return false
            }
        }
        return true
    }
}
