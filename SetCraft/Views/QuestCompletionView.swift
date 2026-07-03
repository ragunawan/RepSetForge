import SwiftUI

/// Snapshot of a quest completion, computed once and handed to QuestCompletionView.
struct QuestCompletionSummary: Identifiable {
    let id = UUID()
    let questName: String
    let distribution: ProgressionService.DistributionResult
    let unlockedAchievements: [Achievement]
}

/// Celebratory summary shown right after a quest is completed: XP earned,
/// muscle breakdown, level-ups, and any newly unlocked achievements.
struct QuestCompletionView: View {
    let summary: QuestCompletionSummary

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SetCraftMetrics.paddingLarge) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.questGold)
                        Text("Quest Complete!")
                            .font(SetCraftFont.title())
                            .foregroundStyle(Color.questNavy)
                        Text(summary.questName)
                            .font(SetCraftFont.body())
                            .foregroundStyle(Color.questNavy.opacity(0.7))
                    }
                    .padding(.top, SetCraftMetrics.paddingLarge)

                    VStack(spacing: SetCraftMetrics.paddingSmall) {
                        QuestCompletionRewardRow(
                            label: "Character",
                            xp: summary.distribution.totalXP,
                            iconName: "person.fill",
                            didLevelUp: summary.distribution.characterLevelUp.didLevelUp
                        )
                        ForEach(sortedMuscleXP, id: \.muscle) { entry in
                            QuestCompletionRewardRow(
                                label: entry.muscle.displayName,
                                xp: entry.xp,
                                iconName: entry.muscle.iconName,
                                didLevelUp: summary.distribution.muscleLevelUps[entry.muscle] != nil
                            )
                        }
                    }
                    .padding(SetCraftMetrics.paddingMedium)
                    .pixelPanel()

                    if !summary.unlockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: SetCraftMetrics.paddingSmall) {
                            Text("Achievements Unlocked")
                                .font(SetCraftFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(summary.unlockedAchievements) { achievement in
                                PixelAchievementCard(achievement: achievement)
                            }
                        }
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity)
                }
                .padding(SetCraftMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
        }
    }

    private var sortedMuscleXP: [(muscle: MuscleGroup, xp: Int)] {
        summary.distribution.muscleXP
            .map { (muscle: $0.key, xp: $0.value) }
            .sorted { $0.xp > $1.xp }
    }
}

#Preview {
    QuestCompletionView(summary: QuestCompletionSummary(
        questName: "Upper Body Strength",
        distribution: ProgressionService.DistributionResult(
            totalXP: 420,
            muscleXP: [.chest: 180, .arms: 72, .shoulders: 90],
            characterLevelUp: .init(oldLevel: 3, newLevel: 4),
            muscleLevelUps: [.chest: .init(oldLevel: 2, newLevel: 3)]
        ),
        unlockedAchievements: []
    ))
}
