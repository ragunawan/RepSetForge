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
    }
}
