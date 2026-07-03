import SwiftUI
import SwiftData

struct QuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]

    @State private var newQuest: Quest?

    private var quests: [Quest] { allQuests.filter { $0.status != .completed } }

    var body: some View {
        List {
            ForEach(quests) { quest in
                NavigationLink(value: quest) {
                    PixelQuestCard(quest: quest)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteQuests)
        }
        .listStyle(.plain)
        .background(Color.questParchment.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("All Quests")
        .navigationDestination(for: Quest.self) { quest in
            QuestDetailView(quest: quest)
        }
        .navigationDestination(item: $newQuest) { quest in
            QuestDetailView(quest: quest)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let quest = Quest(name: "New Quest", status: .active)
                    modelContext.insert(quest)
                    newQuest = quest
                } label: {
                    Label("New Quest", systemImage: "plus.circle.fill")
                }
            }
        }
        .overlay {
            if quests.isEmpty {
                Text("No quests yet. Tap + to start one.")
                    .font(SetCraftFont.body())
                    .foregroundStyle(Color.questNavy.opacity(0.6))
            }
        }
    }

    private func deleteQuests(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(quests[index])
        }
    }
}

#Preview {
    NavigationStack {
        QuestListView()
    }
    .modelContainer(PersistenceController.previewContainer)
}
