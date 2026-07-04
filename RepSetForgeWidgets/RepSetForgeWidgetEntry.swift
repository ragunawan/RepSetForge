import WidgetKit

/// Plain, `SwiftData`-free snapshot of what the widget shows — built once
/// per timeline refresh by `RepSetForgeWidgetProvider`, then just rendered
/// by the view. Keeping the view free of SwiftData means widget previews
/// don't need a `ModelContainer` at all, just sample entries.
struct RepSetForgeWidgetEntry: TimelineEntry {
    let date: Date
    let level: Int
    let title: String
    let currentXP: Int
    let nextLevelXP: Int
    let streakDays: Int
    let activeQuestName: String?
    let activeQuestSkillCount: Int

    static let placeholder = RepSetForgeWidgetEntry(
        date: .now,
        level: 5,
        title: "Iron Trainee",
        currentXP: 240,
        nextLevelXP: 500,
        streakDays: 3,
        activeQuestName: "Upper Body Strength",
        activeQuestSkillCount: 4
    )

    static let empty = RepSetForgeWidgetEntry(
        date: .now,
        level: 1,
        title: "Novice Adventurer",
        currentXP: 0,
        nextLevelXP: 100,
        streakDays: 0,
        activeQuestName: nil,
        activeQuestSkillCount: 0
    )
}
