import SwiftUI

/// Character stat tile: level, title, and XP progress (e.g. "Level 8 · Iron Trainee · 340/800 XP").
struct PixelStatPanel: View {
    let level: Int
    let title: String
    let currentXP: Int
    let nextLevelXP: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SetboundMetrics.paddingSmall) {
            HStack {
                Text("Level \(level)")
                    .font(SetboundFont.heading())
                    .foregroundStyle(Color.questGold)
                Spacer()
                Text(title)
                    .font(SetboundFont.body())
                    .foregroundStyle(Color.questSilver)
            }
            PixelXPBar(currentXP: currentXP, maxXP: nextLevelXP)
            Text("\(currentXP) / \(nextLevelXP) XP")
                .font(SetboundFont.stat(12))
                .foregroundStyle(Color.questSilver.opacity(0.8))
        }
        .padding(SetboundMetrics.paddingMedium)
        .pixelPanel()
    }
}

#Preview {
    PixelStatPanel(level: 8, title: "Iron Trainee", currentXP: 340, nextLevelXP: 800)
        .padding()
        .background(Color.questParchment)
}
