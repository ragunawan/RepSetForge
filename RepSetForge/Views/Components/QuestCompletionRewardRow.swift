import SwiftUI

/// A single XP reward line on the quest completion screen, e.g. "Chest +180 XP".
struct QuestCompletionRewardRow: View {
    let label: String
    let xp: Int
    var iconName: String?
    var didLevelUp: Bool = false

    var body: some View {
        HStack {
            if let iconName {
                Image(systemName: iconName)
                    .foregroundStyle(Color.questGold)
                    .frame(width: 20)
            }
            Text(label)
                .font(RepSetForgeFont.body())
                .foregroundStyle(Color.questSilver)
            if didLevelUp {
                Text("LEVEL UP!")
                    .font(RepSetForgeFont.stat(11))
                    .foregroundStyle(Color.questGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.questGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadiusSmall, style: .circular))
            }
            Spacer()
            Text("+\(xp) XP")
                .font(RepSetForgeFont.stat())
                .foregroundStyle(Color.questGold)
        }
    }
}
