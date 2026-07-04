import SwiftUI
import WidgetKit

struct RepSetForgeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepSetForgeWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Lv \(entry.level)", systemImage: "star.circle.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
            Text(entry.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if entry.streakDays > 0 {
                Label("\(entry.streakDays)-day streak", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let questName = entry.activeQuestName {
                Text(questName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Level \(entry.level)", systemImage: "star.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.currentXP) / \(entry.nextLevelXP) XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if entry.streakDays > 0 {
                    Label("\(entry.streakDays)-day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Quest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let questName = entry.activeQuestName {
                    Text(questName)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text("\(entry.activeQuestSkillCount) skill\(entry.activeQuestSkillCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No active quest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

#Preview("Small", as: .systemSmall) {
    RepSetForgeWidget()
} timeline: {
    RepSetForgeWidgetEntry.placeholder
    RepSetForgeWidgetEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    RepSetForgeWidget()
} timeline: {
    RepSetForgeWidgetEntry.placeholder
    RepSetForgeWidgetEntry.empty
}
