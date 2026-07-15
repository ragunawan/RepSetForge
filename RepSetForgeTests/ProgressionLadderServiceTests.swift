import Testing
import Foundation
@testable import RepSetForge

struct ProgressionLadderServiceTests {
    private func makeSet(weight: Decimal, reps: Int, rpe: Double?, sessionID: UUID, type: SetType = .working) -> SetEntry {
        let session = WorkoutSession(name: "Test")
        session.id = sessionID
        let sessionExercise = SessionExercise(exercise: nil, order: 0)
        sessionExercise.session = session
        let set = SetEntry(index: 0, type: type, weightKg: weight, reps: reps, rpe: rpe)
        set.completedAt = .now
        set.sessionExercise = sessionExercise
        return set
    }

    @Test func ladderGeneratesOneLevelPerRepInRangePlusLevelUp() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 10, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: [])

        #expect(levels.count == 4) // 8, 9, 10, + level-up
        #expect(levels[0].reps == 8)
        #expect(levels[2].reps == 10)
        #expect(levels.last?.isLevelUp == true)
        #expect(levels.last?.weightKg == 102.5)
    }

    @Test func levelCompletesWithEnoughQualifyingSetsInOneSession() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
        let sessionID = UUID()
        let sets = [
            makeSet(weight: 100, reps: 8, rpe: 8, sessionID: sessionID),
            makeSet(weight: 100, reps: 8, rpe: 8, sessionID: sessionID),
        ]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)

        #expect(levels[0].isComplete)
    }

    @Test func levelDoesNotCompleteWithTooFewQualifyingSets() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
        let sets = [makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID())]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)

        #expect(!levels[0].isComplete)
    }

    @Test func qualifyingSetsMustBeInTheSameSession() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 2, incrementKg: 2.5)
        let sets = [
            makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID()),
            makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID()),
        ]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)

        #expect(!levels[0].isComplete)
    }

    @Test func rpeAboveMaxDoesNotQualify() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 8, qualifyingSetsRequired: 1, incrementKg: 2.5)
        let sets = [makeSet(weight: 100, reps: 8, rpe: 9.5, sessionID: UUID())]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)

        #expect(!levels[0].isComplete)
    }

    @Test func warmupSetsDoNotQualify() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 1, incrementKg: 2.5)
        let sets = [makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID(), type: .warmup)]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)

        #expect(!levels[0].isComplete)
    }

    @Test func currentLevelIsTheLowestIncompleteLevel() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 10, maxQualifyingRPE: 9, qualifyingSetsRequired: 1, incrementKg: 2.5)
        let sets = [makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID())]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)
        let current = ProgressionLadderService.currentLevel(in: levels)

        #expect(current?.reps == 9)
    }

    @Test func currentLevelIsLevelUpWhenEverythingIsComplete() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 8, maxQualifyingRPE: 9, qualifyingSetsRequired: 1, incrementKg: 2.5)
        let sets = [makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID())]

        let levels = ProgressionLadderService.ladder(rule: rule, baseWeight: 100, historicalSets: sets)
        let current = ProgressionLadderService.currentLevel(in: levels)

        #expect(current?.isLevelUp == true)
    }

    @Test func baseWeightIsTheMostRecentWorkingSetWeight() {
        let older = makeSet(weight: 90, reps: 8, rpe: 8, sessionID: UUID())
        older.completedAt = Date.now.addingTimeInterval(-1000)
        let newer = makeSet(weight: 100, reps: 8, rpe: 8, sessionID: UUID())
        newer.completedAt = .now

        #expect(ProgressionLadderService.baseWeight(from: [older, newer]) == 100)
    }

    @Test func baseWeightIsNilWithNoHistory() {
        #expect(ProgressionLadderService.baseWeight(from: []) == nil)
    }
}
