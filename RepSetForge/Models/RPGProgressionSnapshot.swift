import Foundation

/// Read-only view of the player's real training progress, decoupled from
/// SwiftData so spawn/boss logic stays pure and testable. Built from
/// PlayerCharacter + completed quests; previews and tests construct it directly.
struct RPGProgressionSnapshot: Equatable, Sendable {
    var currentLevel: Int = 1
    var currentXP: Int = 0
    var totalXP: Int = 0
    var completedWorkoutCount: Int = 0
    var currentWorkoutStreak: Int = 0
    var completedMilestoneQuestIDs: Set<String> = []

    init(
        currentLevel: Int = 1,
        currentXP: Int = 0,
        totalXP: Int = 0,
        completedWorkoutCount: Int = 0,
        currentWorkoutStreak: Int = 0,
        completedMilestoneQuestIDs: Set<String> = []
    ) {
        self.currentLevel = currentLevel
        self.currentXP = currentXP
        self.totalXP = totalXP
        self.completedWorkoutCount = completedWorkoutCount
        self.currentWorkoutStreak = currentWorkoutStreak
        self.completedMilestoneQuestIDs = completedMilestoneQuestIDs
    }

    init(character: PlayerCharacter, completedQuestDates: [Date], state: RPGEncounterState?) {
        self.init(
            currentLevel: character.level,
            currentXP: character.currentXP,
            totalXP: character.totalXP,
            completedWorkoutCount: character.completedQuestCount,
            currentWorkoutStreak: Self.streak(from: completedQuestDates),
            completedMilestoneQuestIDs: Set(state?.completedMilestoneQuestIDs ?? [])
        )
    }

    /// Consecutive-day workout streak ending today or yesterday (a streak isn't
    /// broken until a full day has passed without training).
    static func streak(from completionDates: [Date], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(completionDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        var cursor = today
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
