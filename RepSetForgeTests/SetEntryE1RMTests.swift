import Testing
import Foundation
@testable import RepSetForge

struct SetEntryE1RMTests {
    @Test func epleyFormulaMatchesTheStandardFormula() {
        let weight: Decimal = 100
        let reps = 8
        let set = SetEntry(index: 0, weightKg: weight, reps: reps)
        let expected = weight * (1 + Decimal(reps) / 30)
        #expect(set.estimatedOneRepMax == expected)
    }

    @Test func repsAboveTwelveAreNotValidForE1RM() {
        let set = SetEntry(index: 0, weightKg: 60, reps: 20)
        #expect(set.estimatedOneRepMax == nil)
    }

    @Test func zeroRepsIsNotValidForE1RM() {
        let set = SetEntry(index: 0, weightKg: 60, reps: 0)
        #expect(set.estimatedOneRepMax == nil)
    }

    @Test func missingWeightOrRepsYieldsNilE1RM() {
        #expect(SetEntry(index: 0, weightKg: nil, reps: 8).estimatedOneRepMax == nil)
        #expect(SetEntry(index: 0, weightKg: 100, reps: nil).estimatedOneRepMax == nil)
    }

    @Test func volumeIsWeightTimesReps() {
        let set = SetEntry(index: 0, weightKg: 100, reps: 8)
        #expect(set.volumeKg == 800)
    }

    @Test func volumeIsNilWithoutWeightOrReps() {
        #expect(SetEntry(index: 0, weightKg: nil, reps: 8).volumeKg == nil)
    }

    @Test func warmupSetsDoNotCountTowardVolumeOrPRs() {
        #expect(!SetType.warmup.countsTowardVolumeAndPRs)
        #expect(SetType.working.countsTowardVolumeAndPRs)
        #expect(SetType.drop.countsTowardVolumeAndPRs)
    }
}
