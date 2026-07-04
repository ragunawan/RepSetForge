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

                    // Auto-equip the first skill unlocked in an empty category so
                    // combat isn't silent until the player visits the Gear tab;
                    // never overrides a category the player already has a choice in.
                    let categoryAlreadyEquipped = progressRecords.contains { record in
                        record.equipped && RPGSkillRegistry.skill(id: record.skillID)?.category == skill.category
                    }
                    if !categoryAlreadyEquipped {
                        progress.equipped = true
                    }
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

    /// IDs of the skills actually equipped (one per category at most), which
    /// is what drives passive combat — not just "unlocked."
    static func equippedSkillIDs(context: ModelContext) -> Set<String> {
        equippedSkillIDs(from: (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? [])
    }

    static func equippedSkillIDs(from records: [SkillProgress]) -> Set<String> {
        Set(records.filter { $0.unlocked && $0.equipped }.map(\.skillID))
    }

    /// Equips the given unlocked skill, un-equipping whatever else was
    /// equipped in the same category. No-ops if the skill isn't unlocked.
    static func equip(_ skillID: String, context: ModelContext) {
        guard let target = RPGSkillRegistry.skill(id: skillID) else { return }
        let records = (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? []
        guard let targetRecord = records.first(where: { $0.skillID == skillID && $0.unlocked }) else { return }

        for record in records where record.equipped && record.skillID != skillID {
            if RPGSkillRegistry.skill(id: record.skillID)?.category == target.category {
                record.equipped = false
            }
        }
        targetRecord.equipped = true
    }
}
