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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RepSetForgeMetrics.paddingLarge) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.questGold)
                            .scaleEffect(headerAppeared ? 1 : 0.4)
                            .opacity(headerAppeared ? 1 : 0)
                        Text("Quest Complete!")
                            .font(RepSetForgeFont.title())
                            .foregroundStyle(Color.questNavy)
                        Text(summary.questName)
                            .font(RepSetForgeFont.body())
                            .foregroundStyle(Color.questNavy.opacity(0.7))
                    }
                    .padding(.top, RepSetForgeMetrics.paddingLarge)
                    .onAppear {
                        guard !reduceMotion else {
                            headerAppeared = true
                            return
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            headerAppeared = true
                        }
                    }

                    if !levelUpEntries.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Level Up!")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(levelUpEntries.enumerated()), id: \.element.label) { index, entry in
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(Color.questGreen)
                                    Text(entry.label)
                                        .font(RepSetForgeFont.body(13))
                                        .foregroundStyle(Color.questNavy)
                                    Spacer()
                                    Text("Lv \(entry.oldLevel) → Lv \(entry.newLevel)")
                                        .font(RepSetForgeFont.stat(13))
                                        .foregroundStyle(Color.questGreen)
                                }
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel(border: .questGreen)
                                .staggeredAppearance(index: index)
                            }
                        }
                    }

                    VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                        QuestCompletionRewardRow(
                            label: "Character",
                            xp: summary.distribution.totalXP,
                            iconName: "person.fill",
                            didLevelUp: summary.distribution.characterLevelUp.didLevelUp
                        )
                        .staggeredAppearance(index: 0)
                        ForEach(Array(sortedMuscleXP.enumerated()), id: \.element.muscle) { index, entry in
                            QuestCompletionRewardRow(
                                label: entry.muscle.displayName,
                                xp: entry.xp,
                                iconName: entry.muscle.iconName,
                                didLevelUp: summary.distribution.muscleLevelUps[entry.muscle] != nil
                            )
                            .staggeredAppearance(index: index + 1)
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
                            .staggeredAppearance(index: sortedMuscleXP.count + 1)
                        }
                    }
                    .padding(RepSetForgeMetrics.paddingMedium)
                    .pixelPanel()

                    if !summary.unlockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Achievements Unlocked")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(summary.unlockedAchievements.enumerated()), id: \.element.id) { index, achievement in
                                PixelAchievementCard(achievement: achievement)
                                    .staggeredAppearance(index: index)
                            }
                        }
                    }

                    if !summary.newRecords.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("New Personal Records!")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(summary.newRecords.enumerated()), id: \.offset) { index, record in
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
                                .staggeredAppearance(index: index)
                            }
                        }
                    }

                    if !summary.equipmentDrops.isEmpty {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Equipment Found!")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(Array(summary.equipmentDrops.enumerated()), id: \.offset) { index, drop in
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
                                .staggeredAppearance(index: index)
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
            // Base "you did it" tap whenever the completion screen appears,
            // with heavier feedback layered on top for the bigger wins —
            // more happened, more feedback, without needing distinct
            // per-event SensoryFeedback cases that don't exist.
            .sensoryFeedback(.success, trigger: headerAppeared) { _, appeared in appeared }
            .sensoryFeedback(.impact(weight: .heavy), trigger: headerAppeared) { _, appeared in
                appeared && !levelUpEntries.isEmpty
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: headerAppeared) { _, appeared in
                appeared && !summary.unlockedAchievements.isEmpty
            }
        }
    }

    private var sortedMuscleXP: [(muscle: MuscleGroup, xp: Int)] {
        summary.distribution.muscleXP
            .map { (muscle: $0.key, xp: $0.value) }
            .sorted { $0.xp > $1.xp }
    }

    /// Every level change from this quest, character first then muscle groups
    /// in a stable order — a clear, dedicated summary rather than just the
    /// inline "LEVEL UP!" tags on the XP rows below.
    private var levelUpEntries: [(label: String, oldLevel: Int, newLevel: Int)] {
        var entries: [(label: String, oldLevel: Int, newLevel: Int)] = []
        if summary.distribution.characterLevelUp.didLevelUp {
            let levelUp = summary.distribution.characterLevelUp
            entries.append((label: "Character", oldLevel: levelUp.oldLevel, newLevel: levelUp.newLevel))
        }
        for muscle in MuscleGroup.allCases {
            if let levelUp = summary.distribution.muscleLevelUps[muscle] {
                entries.append((label: muscle.displayName, oldLevel: levelUp.oldLevel, newLevel: levelUp.newLevel))
            }
        }
        return entries
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
