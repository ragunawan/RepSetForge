import SwiftUI
import SwiftData

struct QuestHistoryView: View {
    @Query(sort: \Quest.completedDate, order: .reverse) private var allQuests: [Quest]

    private var completedQuests: [Quest] { allQuests.filter { $0.status == .completed } }

    var body: some View {
        NavigationStack {
            List {
                ForEach(completedQuests) { quest in
                    NavigationLink(value: quest) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.name)
                                .font(SetboundFont.heading(15))
                            HStack(spacing: SetboundMetrics.paddingSmall) {
                                if let completedDate = quest.completedDate {
                                    Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(SetboundFont.body(12))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(quest.exercises.count) skills")
                                    .font(SetboundFont.body(12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("+\(quest.totalXP) XP")
                                    .font(SetboundFont.stat(12))
                                    .foregroundStyle(Color.questGold)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.questParchment.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("History")
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest)
            }
            .overlay {
                if completedQuests.isEmpty {
                    Text("No completed quests yet.")
                        .font(SetboundFont.body())
                        .foregroundStyle(Color.questNavy.opacity(0.6))
                }
            }
        }
    }
}

#Preview {
    QuestHistoryView()
        .modelContainer(PersistenceController.previewContainer)
}
