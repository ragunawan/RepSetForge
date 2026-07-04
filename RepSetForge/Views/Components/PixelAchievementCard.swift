import SwiftUI

/// Achievement display card with locked/unlocked state.
struct PixelAchievementCard: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: RepSetForgeMetrics.paddingMedium) {
            PixelBadge(iconName: achievement.iconName, unlocked: achievement.unlocked)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(RepSetForgeFont.heading(15))
                    .foregroundStyle(achievement.unlocked ? Color.questSilver : Color.questSilver.opacity(0.5))
                Text(achievement.detail)
                    .font(RepSetForgeFont.body(12))
                    .foregroundStyle(Color.questSilver.opacity(0.6))
                if achievement.unlocked, let date = achievement.unlockedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(RepSetForgeFont.stat(11))
                        .foregroundStyle(Color.questGold)
                }
            }
            Spacer()
        }
        .padding(RepSetForgeMetrics.paddingMedium)
        .pixelPanel()
        .opacity(achievement.unlocked ? 1 : 0.75)
        // The badge's SF Symbol (or its "locked" substitute) is the only
        // visual cue for lock state, but its default VoiceOver label alone
        // ("lock", a raw glyph name) doesn't clearly say "locked" — combine
        // everything into one explicit announcement instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.name)
        .accessibilityValue(accessibilityStatus)
    }

    private var accessibilityStatus: String {
        if achievement.unlocked, let date = achievement.unlockedDate {
            return "Unlocked \(date.formatted(date: .abbreviated, time: .omitted)). \(achievement.detail)"
        }
        return "Locked. \(achievement.detail)"
    }
}

#Preview {
    VStack(spacing: 12) {
        PixelAchievementCard(achievement: Achievement(
            key: "first_quest",
            name: "First Quest",
            detail: "Complete your first quest.",
            iconName: "flag.checkered",
            unlocked: true,
            unlockedDate: .now
        ))
        PixelAchievementCard(achievement: Achievement(
            key: "level_10",
            name: "Dungeon Athlete",
            detail: "Reach character level 10.",
            iconName: "star.circle.fill",
            unlocked: false
        ))
    }
    .padding()
    .background(Color.questParchment)
}
