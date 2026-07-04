import Foundation
import SwiftData

/// Owns the app's local SwiftData ModelContainer and seeds baseline progression
/// data (character, muscle tracks, achievement definitions) on first launch.
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    /// Built from `RepSetForgeSchemaV1` (see RepSetForgeSchema.swift) rather
    /// than a flat model list, so the version identifier is embedded and
    /// `RepSetForgeMigrationPlan` can track it across future schema changes.
    static let schema = Schema(versionedSchema: RepSetForgeSchemaV1.self)

    private init(inMemory: Bool = false) {
        // CloudKit-backed for the real on-disk store, at the App Group
        // location `SharedStore` computes (so the widget extension's
        // timeline provider can read it directly and fast, without a
        // CloudKit round-trip inside WidgetKit's strict execution budget).
        // An in-memory store (previews, `inMemory: true` callers) can't
        // sync or share and doesn't need to try. If no iCloud account is
        // signed in (e.g. this simulator), SwiftData falls back to
        // local-only storage rather than failing — sync simply queues
        // until an account becomes available.
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let url = SharedStore.containerURL() {
            config = ModelConfiguration(schema: Self.schema, url: url, cloudKitDatabase: .automatic)
        } else {
            // App Group container unavailable for some provisioning reason —
            // fall back to the default on-disk location rather than fail to
            // launch. The phone app still works and still syncs via
            // CloudKit; only the widget's fast local read is lost.
            config = ModelConfiguration(schema: Self.schema, cloudKitDatabase: .automatic)
        }
        modelContainer = try! ModelContainer(for: Self.schema, migrationPlan: RepSetForgeMigrationPlan.self, configurations: [config])
        modelContext = ModelContext(modelContainer)
        seedCoreDataIfNeeded()
        if ProcessInfo.processInfo.arguments.contains("--preview-data") {
            seedPreviewQuestsIfNeeded()
        }
    }

    private init(container: ModelContainer) {
        modelContainer = container
        modelContext = ModelContext(container)
    }

    func seedCoreDataIfNeeded() {
        if (try? modelContext.fetch(FetchDescriptor<PlayerCharacter>()))?.isEmpty ?? true {
            // `--skip-onboarding` is a deterministic, CI-friendly alternative
            // to manually flipping this bit in the SQLite store after the
            // fact — lets UI tests reach the core app past the first-run
            // onboarding gate without depending on state left over from a
            // previous run on the same simulator.
            let skipOnboarding = ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
            modelContext.insert(PlayerCharacter(hasCompletedOnboarding: skipOnboarding))
        }

        let existingMuscles = (try? modelContext.fetch(FetchDescriptor<MuscleProgress>())) ?? []
        let existingGroups = Set(existingMuscles.map(\.muscleGroup))
        for group in MuscleGroup.allCases where !existingGroups.contains(group) {
            modelContext.insert(MuscleProgress(muscleGroup: group))
        }

        if (try? modelContext.fetch(FetchDescriptor<RPGEncounterState>()))?.isEmpty ?? true {
            modelContext.insert(RPGEncounterState())
        }

        let existingAchievements = (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? []
        let existingKeys = Set(existingAchievements.map(\.key))
        for achievement in AchievementService.seedDefinitions() where !existingKeys.contains(achievement.key) {
            modelContext.insert(achievement)
        }

        SkillProgressionService.seedIfNeeded(context: modelContext)

        try? modelContext.save()
    }

    /// Optional sample data for `--preview-data`: three planned quests with
    /// exercises and unfilled sets, ready to log against.
    func seedPreviewQuestsIfNeeded() {
        guard (try? modelContext.fetch(FetchDescriptor<Quest>()))?.isEmpty ?? true else { return }

        let calendar = Calendar.current
        let now = Date.now

        func makeQuest(
            name: String,
            daysAgo: Int,
            exercises: [(name: String, primary: MuscleGroup, secondary: [MuscleGroup], sets: [(reps: Int, weight: Double)])]
        ) -> Quest {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let quest = Quest(name: name, date: date, status: .planned)
            for spec in exercises {
                let exercise = Exercise(name: spec.name, primaryMuscle: spec.primary, secondaryMuscles: spec.secondary)
                for (index, set) in spec.sets.enumerated() {
                    exercise.sets.append(ExerciseSet(setNumber: index + 1, reps: set.reps, weight: set.weight, completed: false))
                }
                quest.exercises.append(exercise)
            }
            return quest
        }

        let upperBody = makeQuest(name: "Upper Body Strength", daysAgo: 0, exercises: [
            (name: "Bench Press", primary: .chest, secondary: [.shoulders, .arms], sets: [(8, 135), (8, 135), (6, 145)]),
            (name: "Pull-Ups", primary: .back, secondary: [.arms], sets: [(8, 0), (7, 0), (6, 0)]),
            (name: "Shoulder Press", primary: .shoulders, secondary: [.arms], sets: [(10, 65), (10, 65), (8, 70)]),
            (name: "Rows", primary: .back, secondary: [.arms], sets: [(10, 95), (10, 95), (10, 95)])
        ])

        let legDay = makeQuest(name: "Leg Day Dungeon", daysAgo: 1, exercises: [
            (name: "Squat", primary: .legs, secondary: [.core], sets: [(8, 185), (8, 185), (6, 205)]),
            (name: "Romanian Deadlift", primary: .legs, secondary: [.back], sets: [(10, 135), (10, 135), (10, 135)]),
            (name: "Lunges", primary: .legs, secondary: [], sets: [(12, 40), (12, 40), (12, 40)]),
            (name: "Calf Raises", primary: .legs, secondary: [], sets: [(15, 90), (15, 90), (15, 90)])
        ])

        let coreTrial = makeQuest(name: "Core Trial", daysAgo: 2, exercises: [
            (name: "Plank", primary: .core, secondary: [], sets: [(1, 0), (1, 0), (1, 0)]),
            (name: "Hanging Knee Raise", primary: .core, secondary: [.arms], sets: [(12, 0), (12, 0), (10, 0)]),
            (name: "Russian Twist", primary: .core, secondary: [], sets: [(20, 15), (20, 15), (20, 15)])
        ])

        for quest in [upperBody, legDay, coreTrial] {
            modelContext.insert(quest)
        }

        try? modelContext.save()
    }

    @MainActor
    static let previewContainer: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, migrationPlan: RepSetForgeMigrationPlan.self, configurations: [config])
        let controller = PersistenceController(container: container)
        controller.seedCoreDataIfNeeded()
        controller.seedPreviewQuestsIfNeeded()
        return container
    }()
}
