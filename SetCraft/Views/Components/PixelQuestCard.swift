import SwiftUI

/// Card summarizing a quest for list display: name, status, exercise count, XP.
struct PixelQuestCard: View {
    let quest: Quest

    private var statusColor: Color {
        switch quest.status {
        case .planned: return .questSilver
        case .active: return .questGold
        case .completed: return .questGreen
        }
    }

    private var statusIcon: String {
        switch quest.status {
        case .planned: return "hourglass"
        case .active: return "flame.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }

    var body: some View {
        HStack(spacing: SetCraftMetrics.paddingMedium) {
            RoundedRectangle(cornerRadius: 3, style: .circular)
                .fill(statusColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.name)
                    .font(SetCraftFont.heading())
                    .foregroundStyle(Color.questSilver)
                HStack(spacing: SetCraftMetrics.paddingSmall) {
                    Label(quest.status.displayName, systemImage: statusIcon)
                        .font(SetCraftFont.body(12))
                        .foregroundStyle(statusColor)
                    Text("\(quest.exercises.count) skill\(quest.exercises.count == 1 ? "" : "s")")
                        .font(SetCraftFont.body(12))
                        .foregroundStyle(Color.questSilver.opacity(0.7))
                }
            }

            Spacer()

            if quest.totalXP > 0 {
                Text("+\(quest.totalXP) XP")
                    .font(SetCraftFont.stat(13))
                    .foregroundStyle(Color.questGold)
            }
        }
        .padding(SetCraftMetrics.paddingMedium)
        .pixelPanel()
    }
}
