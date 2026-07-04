import SwiftUI

/// Snapshot of a quest completion, computed once and handed to QuestCompletionView.
struct QuestCompletionSummary: Identifiable {
    let id = UUID()
    let questName: String
    let distribution: ProgressionService.DistributionResult
    let unlockedAchievements: [Achievement]
    let newRecords: [PersonalRecordService.Update]
    let goldEarned: Int
    let equipmentDrops: [EquipmentDropService.DropResult]
}

/// Celebratory summary shown right after a quest is completed: XP earned,
/// muscle breakdown, level-ups, and any newly unlocked achievements.
struct QuestCompletionView: View {
    let summary: QuestCompletionSummary

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RepSetForgeMetrics.paddingLarge) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.questGold)
                        Text("Quest Complete!")
                            .font(RepSetForgeFont.title())
                            .foregroundStyle(Color.questNavy)
                        Text(summary.questName)
                            .font(RepSetForgeFont.body())
                            .foregroundStyle(Color.questNavy.opacity(0.7))
                    }
                    .padding(.top, RepSetForgeMetrics.paddingLarge)

                    VStack(spacing: RepSetForgeMetrics.paddingSmall) {
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
                        if summary.goldEarned > 0 {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(Color.questGold)
                                    .frame(width: 20)
                                Text("Gold")
                                    .font(RepSetForgeFont.body())
                                    .foregroundStyle(Color.questSilver)
                                Spacer()
                                Text("+\(summary.goldEarned)")
                                    .font(RepSetForgeFont.stat())
                                    .foregroundStyle(Color.questGold)
                            }
                        }
                    }
                    .padding(RepSetForgeMetrics.paddingMedium)
                    .pixelPanel()

                    if !summary.unlockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Achievements Unlocked")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(summary.unlockedAchievements) { achievement in
                                PixelAchievementCard(achievement: achievement)
                            }
                        }
                    }

                    if !summary.newRecords.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("New Personal Records!")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(summary.newRecords.enumerated()), id: \.offset) { _, record in
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(Color.questGold)
                                    Text("\(record.exerciseName) — \(record.recordType.displayName)")
                                        .font(RepSetForgeFont.body(13))
                                        .foregroundStyle(Color.questNavy)
                                    Spacer()
                                    Text(record.recordType.formattedValue(record.newValue, unit: record.unit ?? .pounds))
                                        .font(RepSetForgeFont.stat(13))
                                        .foregroundStyle(Color.questGold)
                                }
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel()
                            }
                        }
                    }

                    if !summary.equipmentDrops.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Equipment Found!")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(summary.equipmentDrops.enumerated()), id: \.offset) { _, drop in
                                HStack {
                                    Image(systemName: "shippingbox.fill")
                                        .foregroundStyle(Color.questGold)
                                    Text(drop.name)
                                        .font(RepSetForgeFont.body(13))
                                        .foregroundStyle(Color.questNavy)
                                    Spacer()
                                }
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel()
                            }
                        }
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity)
                }
                .padding(RepSetForgeMetrics.paddingLarge)
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
        unlockedAchievements: [],
        newRecords: [],
        goldEarned: 42,
        equipmentDrops: []
    ))
}
