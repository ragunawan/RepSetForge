import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Query private var characters: [PlayerCharacter]

    @State private var entries: [LeaderboardService.Entry] = []
    @State private var currentEntryID: String?
    @State private var loadError: String?
    @State private var isLoading = false

    private var character: PlayerCharacter? { characters.first }

    var body: some View {
        Group {
            if let character, !character.leaderboardOptIn {
                optedOutState
            } else if isLoading {
                ProgressView("Loading leaderboard…")
            } else if let loadError {
                ContentUnavailableView(
                    "Couldn't Load Leaderboard",
                    systemImage: "wifi.slash",
                    description: Text(loadError)
                )
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "list.number",
                    description: Text("Be the first to appear here.")
                )
            } else {
                List(entries) { entry in
                    HStack {
                        Text("#\(LeaderboardService.rank(of: entry.id, in: entries) ?? 0)")
                            .font(RepSetForgeFont.stat(13))
                            .foregroundStyle(Color.questGold)
                            .frame(width: 36, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(RepSetForgeFont.heading(15))
                                .fontWeight(entry.id == currentEntryID ? .bold : .regular)
                            Text("\(entry.completedQuestCount) quests · \(entry.streakDays)-day streak")
                                .font(RepSetForgeFont.body(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Lv \(entry.level)")
                            .font(RepSetForgeFont.stat(14))
                            .foregroundStyle(Color.questGold)
                    }
                    .listRowBackground(entry.id == currentEntryID ? Color.questGold.opacity(0.12) : nil)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Leaderboard")
        .task { await load() }
        .refreshable { await load() }
    }

    private var optedOutState: some View {
        ContentUnavailableView(
            "Leaderboard Opt-In Required",
            systemImage: "chart.bar.xaxis",
            description: Text("Turn on \"Share to Leaderboard\" in Settings to see and appear on the global leaderboard.")
        )
    }

    private func load() async {
        guard let character, character.leaderboardOptIn else { return }
        isLoading = true
        loadError = nil
        do {
            try await LeaderboardService.publish(
                displayName: character.leaderboardDisplayName,
                level: character.level,
                totalXP: character.totalXP,
                streakDays: StreakService.currentStreakLength(
                    completedDays: StreakService.completedDays(from: (try? modelContextQuests()) ?? [])
                ),
                completedQuestCount: character.completedQuestCount
            )
            currentEntryID = try await LeaderboardService.currentEntryID()
            entries = try await LeaderboardService.fetchTopEntries()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    /// `@Query` alone can't fetch `Quest` without also declaring it at the
    /// view level, so this reaches the same completed quests
    /// `StreakService` needs via a plain fetch instead of a second `@Query`.
    private func modelContextQuests() throws -> [Quest] {
        try characters.first?.modelContext?.fetch(FetchDescriptor<Quest>()) ?? []
    }
}

private func optedOutPreviewContainer() -> ModelContainer {
    let container = Fixtures.makeContainer()
    let context = ModelContext(container)
    context.insert(Fixtures.makeCharacter())
    return container
}

#Preview("Opted out") {
    NavigationStack {
        LeaderboardView()
            .modelContainer(optedOutPreviewContainer())
    }
}
