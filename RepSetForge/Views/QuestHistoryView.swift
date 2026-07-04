import SwiftUI
import SwiftData

private enum HistoryDisplayMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
}

struct QuestHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.completedDate, order: .reverse) private var allQuests: [Quest]

    @State private var duplicatedQuest: Quest?
    @State private var displayMode: HistoryDisplayMode = .list

    private var completedQuests: [Quest] { allQuests.filter { $0.status == .completed } }

    var body: some View {
        NavigationStack {
            Group {
                switch displayMode {
                case .list:
                    listView
                case .calendar:
                    ScrollView {
                        QuestCalendarView(quests: completedQuests)
                    }
                }
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Display Mode", selection: $displayMode) {
                        ForEach(HistoryDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest)
            }
            .navigationDestination(item: $duplicatedQuest) { quest in
                QuestDetailView(quest: quest)
            }
            .overlay {
                if completedQuests.isEmpty {
                    Text("No completed quests yet.")
                        .font(RepSetForgeFont.body())
                        .foregroundStyle(Color.questNavy.opacity(0.6))
                }
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(completedQuests) { quest in
                NavigationLink(value: quest) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quest.name)
                            .font(RepSetForgeFont.heading(15))
                        HStack(spacing: RepSetForgeMetrics.paddingSmall) {
                            if let completedDate = quest.completedDate {
                                Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(RepSetForgeFont.body(12))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(quest.exercises.count) skills")
                                .font(RepSetForgeFont.body(12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(quest.totalXP) XP")
                                .font(RepSetForgeFont.stat(12))
                                .foregroundStyle(Color.questGold)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        duplicateQuest(quest)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(Color.questNavy)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func duplicateQuest(_ quest: Quest) {
        let copy = QuestDuplicationService.duplicate(quest)
        modelContext.insert(copy)
        duplicatedQuest = copy
    }
}

#Preview {
    QuestHistoryView()
        .modelContainer(PersistenceController.previewContainer)
}
