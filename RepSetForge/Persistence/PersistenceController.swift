import Foundation
import SwiftData

enum PersistenceController {
    static var schema: Schema {
        Schema([
            AppSettings.self,
            Exercise.self,
            ProgressionRule.self,
            RoutineItem.self,
            Routine.self,
            SetEntry.self,
            SessionExercise.self,
            WorkoutSession.self,
            PRRecord.self,
            BodyMetric.self
        ])
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    @MainActor static func ensureDefaults(context: ModelContext) {
        let settingsCount = (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
        if settingsCount == 0 { context.insert(AppSettings()) }
        try? context.save()
    }

    @MainActor static func resetAll(context: ModelContext) {
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: Routine.self)
        try? context.delete(model: RoutineItem.self)
        try? context.delete(model: Exercise.self)
        try? context.delete(model: PRRecord.self)
        try? context.delete(model: BodyMetric.self)
        try? context.delete(model: AppSettings.self)
        ensureDefaults(context: context)
    }

    @MainActor static func seedDemoData(context: ModelContext) {
        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard exerciseCount == 0 else { return }
        let bench = Exercise(name: "Bench Press", primary: .chest, secondary: [.shoulders, .arms], equipment: .barbell, isFavorite: true)
        let row = Exercise(name: "Cable Row", primary: .back, secondary: [.arms], equipment: .cable)
        let squat = Exercise(name: "Back Squat", primary: .legs, secondary: [.core], equipment: .barbell)
        let press = Exercise(name: "Shoulder Press", primary: .shoulders, secondary: [.arms], equipment: .dumbbell)
        [bench, row, squat, press].forEach(context.insert)

        let routine = Routine(name: "Push Day A", items: [
            RoutineItem(exercise: bench, order: 0),
            RoutineItem(exercise: press, order: 1)
        ])
        context.insert(routine)

        let pull = Routine(name: "Pull Day B", items: [RoutineItem(exercise: row, order: 0)])
        pull.lastPerformedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        context.insert(pull)

        for i in 0..<8 {
            context.insert(BodyMetric(date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(), bodyweightKg: 82.6 - Double(i) * 0.08, bodyFatPct: 17.8 - Double(i) * 0.04))
        }
        try? context.save()
    }
}
