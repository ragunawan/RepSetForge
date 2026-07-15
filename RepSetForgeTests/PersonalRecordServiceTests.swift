import Testing
import Foundation
import SwiftData
@testable import RepSetForge

struct PersonalRecordServiceTests {
    /// Uses the real app schema (not a hand-picked subset) — a partial
    /// schema risks runtime errors the moment a relationship points at a
    /// model type that isn't included.
    private func makeContext() -> ModelContext {
        let schema = Schema(RepSetForgeSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func firstSetCreatesRecordsForEveryQualifyingKind() {
        let context = makeContext()
        let exercise = Exercise(name: "Bench Press", equipment: .barbell)
        let set = SetEntry(index: 0, weightKg: 100, reps: 8)
        set.completedAt = .now

        let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: [], context: context)

        #expect(newRecords.count == 3)
        #expect(set.isPR)
        #expect(newRecords.contains { $0.kind == .bestWeight && $0.value == 100 })
        #expect(newRecords.contains { $0.kind == .bestVolume && $0.value == 800 })
    }

    @Test func heavierWeightUpdatesExistingRecordInPlace() {
        let context = makeContext()
        let exercise = Exercise(name: "Squat", equipment: .barbell)
        let existing = PRRecord(exercise: exercise, kind: .bestWeight, value: 100)
        let set = SetEntry(index: 0, weightKg: 110, reps: 5)
        set.completedAt = .now

        let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: [existing], context: context)

        #expect(newRecords.contains { $0 === existing })
        #expect(existing.value == 110)
    }

    @Test func lighterWeightIsNotAPR() {
        let context = makeContext()
        let exercise = Exercise(name: "Deadlift", equipment: .barbell)
        let existing = PRRecord(exercise: exercise, kind: .bestWeight, value: 150)
        let set = SetEntry(index: 0, weightKg: 100, reps: 8)
        set.completedAt = .now

        let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: [existing], context: context)

        #expect(!newRecords.contains { $0.kind == .bestWeight })
        #expect(existing.value == 150)
    }

    @Test func warmupSetsNeverProduceRecords() {
        let context = makeContext()
        let exercise = Exercise(name: "Overhead Press", equipment: .barbell)
        let set = SetEntry(index: 0, type: .warmup, weightKg: 200, reps: 8)
        set.completedAt = .now

        let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: [], context: context)

        #expect(newRecords.isEmpty)
        #expect(!set.isPR)
    }

    @Test func incompleteSetProducesNoRecords() {
        let context = makeContext()
        let exercise = Exercise(name: "Row", equipment: .barbell)
        let set = SetEntry(index: 0, weightKg: nil, reps: 8)

        let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: [], context: context)

        #expect(newRecords.isEmpty)
    }
}
