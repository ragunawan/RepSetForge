import Foundation
import SwiftData

/// Feeds real training XP into `SkillProgress`: a set's primary muscle grants
/// 100% of its exercise XP to related skills, secondary muscles grant 40%,
/// and a personal record grants a flat bonus — replacing pure character-level
/// skill unlocks with skills earned from the muscles that actually trained them.
enum SkillProgressionService {
    static let personalRecordSkillXPBonus = 50

    struct SkillUnlock {
        let skillID: String
        let name: String
    }

    /// Seeds one SkillProgress row per catalog skill. Idempotent — only adds
    /// rows for skills that don't have one yet, safe to call every launch.
    @discardableResult
    static func seedIfNeeded(context: ModelContext) -> [SkillProgress] {
        let existing = (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? []
        let existingIDs = Set(existing.map(\.skillID))
        var seeded: [SkillProgress] = []
        for skill in RPGSkillRegistry.all where !existingIDs.contains(skill.id) {
            let progress = SkillProgress(skillID: skill.id)
            context.insert(progress)
            seeded.append(progress)
        }
        return seeded
    }

    /// Distributes skill XP for the given exercises' completed sets and any
    /// personal records they set this quest, unlocking any skill whose
    /// accumulated XP has crossed its threshold. Returns newly unlocked skills.
    @discardableResult
    static func distributeSkillXP(
        exercises: [Exercise],
        prExerciseNames: Set<String> = [],
        context: ModelContext,
        at date: Date = .now
    ) -> [SkillUnlock] {
        let progressRecords = (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: progressRecords.map { ($0.skillID, $0) })
        var newlyUnlocked: [SkillUnlock] = []

        func grant(muscle: MuscleGroup, amount: Int) {
            guard amount > 0 else { return }
            for skill in RPGSkillRegistry.all where skill.relatedMuscles.contains(muscle) {
                guard let progress = byID[skill.id] else { continue }
                progress.currentXP += amount
                progress.totalXP += amount
                if !progress.unlocked && progress.totalXP >= skill.unlockThresholdXP {
                    progress.unlocked = true
                    progress.unlockedDate = date
                    newlyUnlocked.append(SkillUnlock(skillID: skill.id, name: skill.name))
                }
            }
        }

        for exercise in exercises {
            let xp = ProgressionService.exerciseXP(exercise)
            if xp > 0 {
                grant(muscle: exercise.primaryMuscle, amount: xp)
                for secondary in exercise.secondaryMuscles {
                    grant(muscle: secondary, amount: Int((Double(xp) * 0.4).rounded()))
                }
            }
            if prExerciseNames.contains(exercise.name) {
                grant(muscle: exercise.primaryMuscle, amount: personalRecordSkillXPBonus)
            }
        }

        return newlyUnlocked
    }

    /// IDs of skills unlocked via accumulated skill XP, for gating passive
    /// combat skill selection instead of pure character level.
    static func unlockedSkillIDs(context: ModelContext) -> Set<String> {
        unlockedSkillIDs(from: (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? [])
    }

    static func unlockedSkillIDs(from records: [SkillProgress]) -> Set<String> {
        Set(records.filter(\.unlocked).map(\.skillID))
    }
}
