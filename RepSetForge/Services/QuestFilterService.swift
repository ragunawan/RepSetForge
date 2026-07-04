import Foundation

/// Search text plus optional filter dimensions for browsing quests. All
/// fields are independent — `nil`/empty means "don't filter on this."
struct QuestFilterCriteria: Equatable {
    var searchText: String = ""
    var muscleGroup: MuscleGroup?
    var status: QuestStatus?
    var startDate: Date?
    var endDate: Date?
    var minXP: Int?
    var maxXP: Int?

    var isActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || muscleGroup != nil || status != nil || startDate != nil || endDate != nil || minXP != nil || maxXP != nil
    }
}

/// Pure quest search/filter logic behind `QuestListView`'s search bar and
/// filter sheet — no persisted state of its own.
enum QuestFilterService {
    static func filter(_ quests: [Quest], criteria: QuestFilterCriteria) -> [Quest] {
        quests.filter { quest in
            matchesSearchText(quest, criteria.searchText)
                && matchesMuscleGroup(quest, criteria.muscleGroup)
                && matchesStatus(quest, criteria.status)
                && matchesDateRange(quest, start: criteria.startDate, end: criteria.endDate)
                && matchesXPRange(quest, min: criteria.minXP, max: criteria.maxXP)
        }
    }

    private static func matchesSearchText(_ quest: Quest, _ searchText: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if quest.name.localizedCaseInsensitiveContains(trimmed) { return true }
        return quest.exercises.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private static func matchesMuscleGroup(_ quest: Quest, _ muscleGroup: MuscleGroup?) -> Bool {
        guard let muscleGroup else { return true }
        return quest.exercises.contains { $0.primaryMuscle == muscleGroup || $0.secondaryMuscles.contains(muscleGroup) }
    }

    private static func matchesStatus(_ quest: Quest, _ status: QuestStatus?) -> Bool {
        guard let status else { return true }
        return quest.status == status
    }

    private static func matchesDateRange(_ quest: Quest, start: Date?, end: Date?) -> Bool {
        if let start, quest.date < start { return false }
        if let end, quest.date > end { return false }
        return true
    }

    private static func matchesXPRange(_ quest: Quest, min: Int?, max: Int?) -> Bool {
        if let min, quest.totalXP < min { return false }
        if let max, quest.totalXP > max { return false }
        return true
    }
}
