import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var achievements: [Achievement]

    private var sorted: [Achievement] {
        achievements.sorted { lhs, rhs in
            switch (lhs.unlockedDate, rhs.unlockedDate) {
            case let (l?, r?): return l < r
            case (nil, nil): return lhs.name < rhs.name
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    private var unlockedCount: Int { achievements.filter(\.unlocked).count }

    /// Encouraging framing for a fresh save (all locked) vs. genuine progress,
    /// so a wall of lock icons doesn't read as purely discouraging.
    private var progressSubtitle: String {
        guard !achievements.isEmpty else { return "" }
        if unlockedCount == 0 {
            return "Complete quests to start unlocking these."
        }
        if unlockedCount == achievements.count {
            return "All achievements unlocked!"
        }
        return "Keep training to unlock the rest."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: RepSetForgeMetrics.paddingSmall) {
                    if !achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(unlockedCount) of \(achievements.count) Unlocked")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            Text(progressSubtitle)
                                .font(RepSetForgeFont.body(13))
                                .foregroundStyle(Color.questNavy.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, RepSetForgeMetrics.paddingSmall)
                    }
                    ForEach(sorted) { achievement in
                        PixelAchievementCard(achievement: achievement)
                    }
                }
                .padding(RepSetForgeMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("Achievements")
        }
    }
}

#Preview("Empty — none unlocked") {
    AchievementsView()
        .modelContainer(PersistenceController.previewContainer)
}

private func achievementsPreviewContainer(unlockedCount: Int) -> ModelContainer {
    let schema = Schema([Achievement.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)
    for (index, achievement) in AchievementService.seedDefinitions().enumerated() {
        if index < unlockedCount {
            achievement.unlocked = true
            achievement.unlockedDate = .now
        }
        context.insert(achievement)
    }
    return container
}

#Preview("Partially unlocked") {
    AchievementsView()
        .modelContainer(achievementsPreviewContainer(unlockedCount: 4))
}

#Preview("All unlocked") {
    AchievementsView()
        .modelContainer(achievementsPreviewContainer(unlockedCount: AchievementService.definitions.count))
}
