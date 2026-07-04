import AppIntents
import SwiftData

/// Thin `AppIntent` wrappers around `AppIntentService` — all real logic
/// lives there so it stays unit-testable; these just bridge to
/// `PersistenceController.shared` (the same container the running app uses)
/// and translate results into Shortcuts/Siri dialog responses.
///
/// Deliberately *not* `@MainActor` at the type level: `AppShortcutsProvider`
/// constructs these from a synchronous, non-isolated static property, so a
/// type-level `@MainActor` would conflict with that. Each `perform()` hops
/// to the main actor itself instead, since `PersistenceController` is
/// `@MainActor`-isolated.

struct StartQuestIntent: AppIntent {
    static let title: LocalizedStringResource = "Start New Quest"
    static let description = IntentDescription("Starts a new active quest in RepSetForge.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Discard the returned Quest inside the closure — PersistentModels
        // aren't Sendable, so only a Void (or other Sendable) result may
        // cross back out of MainActor.run.
        await MainActor.run {
            _ = AppIntentService.startQuest(context: PersistenceController.shared.modelContext)
        }
        return .result(dialog: "Started a new quest!")
    }
}

struct LogSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Set"
    static let description = IntentDescription("Logs a completed set to your current active quest in RepSetForge.")

    @Parameter(title: "Exercise Name")
    var exerciseName: String

    @Parameter(title: "Reps", default: 10)
    var reps: Int

    @Parameter(title: "Weight", default: 0)
    var weight: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$reps) reps of \(\.$exerciseName) at \(\.$weight)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog: IntentDialog = await MainActor.run {
            let context = PersistenceController.shared.modelContext
            let character = (try? context.fetch(FetchDescriptor<PlayerCharacter>()))?.first
            let unit = character?.preferredWeightUnit ?? .pounds

            do {
                let result = try AppIntentService.logSet(
                    exerciseName: exerciseName,
                    reps: reps,
                    weight: weight,
                    weightUnit: unit,
                    context: context
                )
                return IntentDialog(stringLiteral: "Logged \(reps) reps of \(result.exerciseName) to \(result.questName).")
            } catch {
                return IntentDialog(stringLiteral: error.localizedDescription)
            }
        }
        return .result(dialog: dialog)
    }
}

struct ViewCurrentLevelIntent: AppIntent {
    static let title: LocalizedStringResource = "View Current Level"
    static let description = IntentDescription("Shows your current RepSetForge character level.")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let summary = await MainActor.run {
            AppIntentService.currentLevelSummary(context: PersistenceController.shared.modelContext)
        }
        return .result(value: summary.level, dialog: "You're level \(summary.level) — \(summary.title).")
    }
}

struct RepSetForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartQuestIntent(),
            phrases: [
                "Start a new quest in \(.applicationName)",
                "Start a workout in \(.applicationName)"
            ],
            shortTitle: "Start Quest",
            systemImageName: "flag.checkered"
        )
        AppShortcut(
            intent: LogSetIntent(),
            phrases: ["Log a set in \(.applicationName)"],
            shortTitle: "Log Set",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: ViewCurrentLevelIntent(),
            phrases: [
                "What's my level in \(.applicationName)",
                "Check my level in \(.applicationName)"
            ],
            shortTitle: "Current Level",
            systemImageName: "star.circle"
        )
    }
}
