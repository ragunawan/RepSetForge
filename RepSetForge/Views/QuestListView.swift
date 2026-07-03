import SwiftUI
import SwiftData

struct QuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]
    @Query(sort: \QuestTemplate.name) private var questTemplates: [QuestTemplate]

    @State private var newQuest: Quest?
    @State private var showingManageQuestTemplates = false

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
                newQuestMenu
            }
        }
        .sheet(isPresented: $showingManageQuestTemplates) {
            ManageQuestTemplatesSheet()
        }
        .overlay {
            if quests.isEmpty {
                Text("No quests yet. Tap + to start one.")
                    .font(RepSetForgeFont.body())
                    .foregroundStyle(Color.questNavy.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private var newQuestMenu: some View {
        Menu {
            Button {
                startBlankQuest()
            } label: {
                Label("Blank Quest", systemImage: "doc.badge.plus")
            }
            if !questTemplates.isEmpty {
                Menu {
                    ForEach(questTemplates) { template in
                        Button(template.name) { startQuest(from: template) }
                    }
                } label: {
                    Label("From Template", systemImage: "square.stack.3d.up.fill")
                }
            }
            Button {
                showingManageQuestTemplates = true
            } label: {
                Label("Manage Quest Templates", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Label("New Quest", systemImage: "plus.circle.fill")
        }
    }

    private func startBlankQuest() {
        let quest = Quest(name: "New Quest", status: .active)
        modelContext.insert(quest)
        newQuest = quest
    }

    private func startQuest(from template: QuestTemplate) {
        let quest = QuestTemplateService.makeQuest(from: template)
        modelContext.insert(quest)
        newQuest = quest
    }

    private func deleteQuests(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(quests[index])
        }
    }
}

private struct ManageQuestTemplatesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QuestTemplate.name) private var templates: [QuestTemplate]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if templates.isEmpty {
                        Text("No saved quest templates yet. Save one from a quest's detail screen.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates) { template in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(RepSetForgeFont.heading(15))
                                Text(skillSummary(for: template))
                                    .font(RepSetForgeFont.body(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }
            }
            .navigationTitle("Quest Templates")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func skillSummary(for template: QuestTemplate) -> String {
        let count = template.exerciseBlueprints.count
        return count == 1 ? "1 skill" : "\(count) skills"
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        QuestListView()
    }
    .modelContainer(PersistenceController.previewContainer)
}
