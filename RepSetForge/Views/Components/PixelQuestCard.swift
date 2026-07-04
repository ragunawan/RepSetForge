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
        HStack(spacing: RepSetForgeMetrics.paddingMedium) {
            RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadiusSmall, style: .circular)
                .fill(statusColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.name)
                    .font(RepSetForgeFont.heading())
                    .foregroundStyle(Color.questSilver)
                HStack(spacing: RepSetForgeMetrics.paddingSmall) {
                    Label(quest.status.displayName, systemImage: statusIcon)
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(statusColor)
                    Text("\(quest.exercises.count) skill\(quest.exercises.count == 1 ? "" : "s")")
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(Color.questSilver.opacity(0.7))
                }
            }

            Spacer()

            if quest.totalXP > 0 {
                Text("+\(quest.totalXP) XP")
                    .font(RepSetForgeFont.stat(13))
                    .foregroundStyle(Color.questGold)
            }
        }
        .padding(RepSetForgeMetrics.paddingMedium)
        .pixelPanel()
    }
}

#Preview {
    let planned = Quest(name: "Leg Day Dungeon", status: .planned)
    planned.exercises = [Exercise(name: "Squat", primaryMuscle: .legs)]

    let active = Quest(name: "Upper Body Strength", status: .active)
    active.exercises = [Exercise(name: "Bench Press", primaryMuscle: .chest), Exercise(name: "Rows", primaryMuscle: .back)]

    let completed = Quest(name: "Core Trial", status: .completed)
    completed.exercises = [Exercise(name: "Plank", primaryMuscle: .core)]
    completed.totalXP = 120

    return VStack(spacing: 12) {
        PixelQuestCard(quest: planned)
        PixelQuestCard(quest: active)
        PixelQuestCard(quest: completed)
    }
    .padding()
    .background(Color.questParchment)
}
