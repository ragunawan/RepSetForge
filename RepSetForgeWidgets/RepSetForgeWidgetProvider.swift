import WidgetKit
import SwiftData

struct RepSetForgeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RepSetForgeWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RepSetForgeWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RepSetForgeWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Streak/level/active-quest change at most a few times a day, and
        // WidgetKit budgets refreshes anyway — hourly is frequent enough
        // without wasting the app's daily refresh allowance.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> RepSetForgeWidgetEntry {
        let context = ModelContext(SharedStore.makeReadOnlyContainer())

        guard let character = (try? context.fetch(FetchDescriptor<PlayerCharacter>()))?.first else {
            return .empty
        }

        let allQuests = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        let completedDays = StreakService.completedDays(from: allQuests)
        let streakDays = StreakService.currentStreakLength(completedDays: completedDays)
        let activeQuest = allQuests
            .filter { $0.status != .completed }
            .sorted { $0.date > $1.date }
            .first

        return RepSetForgeWidgetEntry(
            date: .now,
            level: character.level,
            title: character.title,
            currentXP: character.currentXP,
            nextLevelXP: character.nextLevelXP,
            streakDays: streakDays,
            activeQuestName: activeQuest?.name,
            activeQuestSkillCount: activeQuest?.exercises.count ?? 0
        )
    }
}
