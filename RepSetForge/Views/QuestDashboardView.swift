import SwiftUI
import SwiftData

struct QuestDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]

    private var character: PlayerCharacter? { characters.first }
    private var activeQuests: [Quest] { allQuests.filter { $0.status != .completed } }

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
                    RPGSceneView()

                    if let character {
                        PixelStatPanel(
                            level: character.level,
                            title: character.title,
                            currentXP: character.currentXP,
                            nextLevelXP: character.nextLevelXP
                        )

                        HStack {
                            Text("Quests Completed")
                                .font(RepSetForgeFont.body())
                                .foregroundStyle(Color.questNavy)
                            Spacer()
                            Text("\(character.completedQuestCount)")
                                .font(RepSetForgeFont.stat())
                                .foregroundStyle(Color.questNavy)
                        }
                    }

                    PixelDivider()

                    if let quest = activeQuests.first {
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text("Current Quest")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            NavigationLink(value: quest) {
                                PixelQuestCard(quest: quest)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(spacing: RepSetForgeMetrics.paddingMedium) {
                            Text("No active quest")
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            Text("Begin a new quest to start earning XP.")
                                .font(RepSetForgeFont.body(13))
                                .foregroundStyle(Color.questNavy.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(RepSetForgeMetrics.paddingLarge)
                        .pixelPanel(fill: .questNavy.opacity(0.05), border: .questGold)
                    }

                    VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                        Button("Start New Quest") {
                            startNewQuest()
                        }
                        .buttonStyle(.pixel)
                        .frame(maxWidth: .infinity)

                        NavigationLink("View All Quests") {
                            QuestListView()
                        }
                        .font(RepSetForgeFont.body())
                        .foregroundStyle(Color.questNavy)
                    }
                }
                .padding(RepSetForgeMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("RepSetForge")
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest)
            }
        }
    }

    private func startNewQuest() {
        let quest = Quest(name: "New Quest", status: .active)
        modelContext.insert(quest)
        path.append(quest)
    }
}

#Preview {
    QuestDashboardView()
        .modelContainer(PersistenceController.previewContainer)
}
