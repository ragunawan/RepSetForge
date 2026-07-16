import Testing
import Foundation
import SwiftData
@testable import RepSetForge

/// `PersonalRecordService.recompute` — the historical edit invalidation
/// chain's PR-rebuild step (dev spec §5). Separate file from
/// `PersonalRecordServiceTests` since this exercises a distinct, more
/// involved code path (full chronological replay) with its own setup.
struct PersonalRecordRecomputeTests {
    private func makeContext() -> ModelContext {
        let schema = Schema(RepSetForgeSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeSet(index: Int, weightKg: Decimal, reps: Int, secondsAgo: Double, now: Date, exercise: Exercise) -> SetEntry {
        let set = SetEntry(index: index, weightKg: weightKg, reps: reps)
        set.completedAt = now.addingTimeInterval(-secondsAgo)
        let sessionExercise = SessionExercise(exercise: exercise, order: 0)
        sessionExercise.setEntries = [set]
        set.sessionExercise = sessionExercise
        return set
    }

    @Test func replayMarksOnlyTheSetsThatImprovedOnTheRunningBest() {
        let context = makeContext()
        let exercise = Exercise(name: "Bench Press", equipment: .barbell)
        let now = Date.now
        let set1 = makeSet(index: 0, weightKg: 80, reps: 5, secondsAgo: 300, now: now, exercise: exercise)
        let set2 = makeSet(index: 0, weightKg: 90, reps: 5, secondsAgo: 200, now: now, exercise: exercise)
        let set3 = makeSet(index: 0, weightKg: 85, reps: 5, secondsAgo: 100, now: now, exercise: exercise)

        PersonalRecordService.recompute(exercise: exercise, allSets: [set1, set2, set3], existingRecords: [], context: context)

        #expect(set1.isPR)
        #expect(set2.isPR)
        #expect(!set3.isPR)
    }

    @Test func editingAnEarlierSetCanUnPRALaterOne() {
        let context = makeContext()
        let exercise = Exercise(name: "Bench Press", equipment: .barbell)
        let now = Date.now
        let set1 = makeSet(index: 0, weightKg: 80, reps: 5, secondsAgo: 300, now: now, exercise: exercise)
        let set2 = makeSet(index: 0, weightKg: 90, reps: 5, secondsAgo: 200, now: now, exercise: exercise)
        let set3 = makeSet(index: 0, weightKg: 85, reps: 5, secondsAgo: 100, now: now, exercise: exercise)
        let record = PRRecord(exercise: exercise, kind: .bestWeight, value: 90, setEntry: set2)

        // Editing the earliest set upward retroactively un-PRs set2, which
        // only ever beat the old (lower) value at set1.
        set1.weightKg = 95

        PersonalRecordService.recompute(exercise: exercise, allSets: [set1, set2, set3], existingRecords: [record], context: context)

        #expect(set1.isPR)
        #expect(!set2.isPR)
        #expect(!set3.isPR)
        #expect(record.value == 95)
        #expect(record.setEntry === set1)
    }

    @Test func deletingTheCurrentPRFallsBackToTheNextBestRemainingSet() {
        let context = makeContext()
        let exercise = Exercise(name: "Bench Press", equipment: .barbell)
        let now = Date.now
        let set1 = makeSet(index: 0, weightKg: 80, reps: 5, secondsAgo: 300, now: now, exercise: exercise)
        let set2 = makeSet(index: 0, weightKg: 90, reps: 5, secondsAgo: 200, now: now, exercise: exercise)
        let set3 = makeSet(index: 0, weightKg: 85, reps: 5, secondsAgo: 100, now: now, exercise: exercise)
        let record = PRRecord(exercise: exercise, kind: .bestWeight, value: 90, setEntry: set2)

        // set2 (the current PR) is deleted — the caller is expected to have
        // already removed it from the model context; recompute just needs
        // it excluded from `allSets`.
        PersonalRecordService.recompute(exercise: exercise, allSets: [set1, set3], existingRecords: [record], context: context)

        #expect(set1.isPR)
        #expect(set3.isPR)
        #expect(record.value == 85)
        #expect(record.setEntry === set3)
    }

    @Test func noQualifyingSetsLeftDeletesTheRecord() {
        let context = makeContext()
        let exercise = Exercise(name: "Bench Press", equipment: .barbell)
        let record = PRRecord(exercise: exercise, kind: .bestWeight, value: 90)
        context.insert(record)

        PersonalRecordService.recompute(exercise: exercise, allSets: [], existingRecords: [record], context: context)

        let remaining = try? context.fetch(FetchDescriptor<PRRecord>())
        #expect(remaining?.isEmpty ?? false)
    }
}
