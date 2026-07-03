import Foundation

/// XP calculation and leveling rules shared by quest completion and the character sheet.
enum ProgressionService {

    struct LevelUpResult {
        let oldLevel: Int
        let newLevel: Int
        var didLevelUp: Bool { newLevel > oldLevel }
    }

    struct DistributionResult {
        let totalXP: Int
        let muscleXP: [MuscleGroup: Int]
        let characterLevelUp: LevelUpResult
        let muscleLevelUps: [MuscleGroup: LevelUpResult]
    }

    /// XP for one logged set: base = reps × 2, bonus = weight (in pounds) / 10.
    /// `weight` is normalized from `unit` to pounds first so the same lift
    /// awards the same XP regardless of which unit it was logged in.
    static func setXP(reps: Int, weight: Double, unit: WeightUnit = .pounds) -> Int {
        let base = Double(reps * 2)
        let bonus = unit.convert(weight, to: .pounds) / 10
        return Int((base + bonus).rounded())
    }

    /// XP for duration-held work (planks, timed circuits): 1 XP every 2 seconds
    /// under tension, roughly comparable in scale to a strength set.
    static func durationXP(seconds: Int) -> Int {
        Int((Double(seconds) / 2).rounded())
    }

    /// XP for distance-based cardio (runs, rows, rides): 20 XP per mile covered.
    static func distanceXP(miles: Double) -> Int {
        Int((miles * 20).rounded())
    }

    /// XP for one logged set, using the formula appropriate to the exercise's
    /// type: reps/weight for strength-like sets, held time for duration sets,
    /// distance for pure-distance sets, and both combined for cardio.
    static func setXP(exercise: Exercise, set: ExerciseSet) -> Int {
        switch exercise.exerciseType {
        case .strength, .bodyweight, .assisted:
            return setXP(reps: set.reps, weight: set.weight, unit: set.weightUnit)
        case .duration:
            return durationXP(seconds: set.durationSeconds)
        case .distance:
            return distanceXP(miles: set.distanceMiles)
        case .cardio:
            return distanceXP(miles: set.distanceMiles) + durationXP(seconds: set.durationSeconds)
        }
    }

    /// XP an exercise contributes, summed from its completed sets only.
    static func exerciseXP(_ exercise: Exercise) -> Int {
        exercise.completedSets.reduce(0) { $0 + setXP(exercise: exercise, set: $1) }
    }

    /// Total XP for a quest, summed across all its exercises.
    static func questXP(exercises: [Exercise]) -> Int {
        exercises.reduce(0) { $0 + exerciseXP($1) }
    }

    /// Awards quest XP to the character and to each affected muscle group, then
    /// applies any level-ups. Primary muscle gets 100% of an exercise's XP,
    /// secondary muscles get 40% each; the character gets 100% of the quest total.
    @discardableResult
    static func distributeXP(
        questXP: Int,
        exercises: [Exercise],
        to character: PlayerCharacter,
        and muscles: [MuscleProgress]
    ) -> DistributionResult {
        var muscleXPTotals: [MuscleGroup: Int] = [:]
        for exercise in exercises {
            let xp = exerciseXP(exercise)
            guard xp > 0 else { continue }
            muscleXPTotals[exercise.primaryMuscle, default: 0] += xp
            for secondary in exercise.secondaryMuscles {
                muscleXPTotals[secondary, default: 0] += Int((Double(xp) * 0.4).rounded())
            }
        }

        let characterOldLevel = character.level
        character.currentXP += questXP
        character.totalXP += questXP
        levelUpIfNeeded(character: character)

        var muscleLevelUps: [MuscleGroup: LevelUpResult] = [:]
        for muscle in muscles {
            guard let awarded = muscleXPTotals[muscle.muscleGroup], awarded > 0 else { continue }
            let oldLevel = muscle.level
            muscle.currentXP += awarded
            muscle.totalXP += awarded
            levelUpIfNeeded(muscle: muscle)
            if muscle.level > oldLevel {
                muscleLevelUps[muscle.muscleGroup] = LevelUpResult(oldLevel: oldLevel, newLevel: muscle.level)
            }
        }

        return DistributionResult(
            totalXP: questXP,
            muscleXP: muscleXPTotals,
            characterLevelUp: LevelUpResult(oldLevel: characterOldLevel, newLevel: character.level),
            muscleLevelUps: muscleLevelUps
        )
    }

    /// nextLevelXP = currentLevel × 100. Levels up (possibly multiple times) while
    /// XP meets the threshold, carrying over excess XP, then refreshes the title.
    static func levelUpIfNeeded(character: PlayerCharacter) {
        while character.currentXP >= character.nextLevelXP {
            character.currentXP -= character.nextLevelXP
            character.level += 1
        }
        character.title = title(for: character.level)
    }

    static func levelUpIfNeeded(muscle: MuscleProgress) {
        while muscle.currentXP >= muscle.nextLevelXP {
            muscle.currentXP -= muscle.nextLevelXP
            muscle.level += 1
        }
    }

    static func title(for level: Int) -> String {
        switch level {
        case ..<5: return "Novice Adventurer"
        case 5..<10: return "Iron Trainee"
        case 10..<15: return "Dungeon Athlete"
        case 15..<20: return "Strength Knight"
        case 20..<25: return "Elite Champion"
        default: return "Mythic Hero"
        }
    }
}
