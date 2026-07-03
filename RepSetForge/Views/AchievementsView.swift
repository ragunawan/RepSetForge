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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: RepSetForgeMetrics.paddingSmall) {
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

#Preview {
    AchievementsView()
        .modelContainer(PersistenceController.previewContainer)
}
