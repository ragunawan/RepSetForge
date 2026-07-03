import SwiftUI
import SwiftData

struct QuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]
    @Query(sort: \QuestTemplate.name) private var questTemplates: [QuestTemplate]

    @State private var newQuest: Quest?
    @State private var showingManageQuestTemplates = false
    @State private var showingScheduleQuest = false

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
        .sheet(isPresented: $showingScheduleQuest) {
            ScheduleQuestSheet { quest in
                newQuest = quest
            }
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
                showingScheduleQuest = true
            } label: {
                Label("Schedule Quest…", systemImage: "calendar.badge.plus")
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

private struct ScheduleQuestSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QuestTemplate.name) private var templates: [QuestTemplate]

    let onCreate: (Quest) -> Void

    @State private var name = "New Quest"
    @State private var date = Date.now
    @State private var selectedTemplate: QuestTemplate?

    var body: some View {
        NavigationStack {
            Form {
                Section("Quest") {
                    TextField("Name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                if !templates.isEmpty {
                    Section("Start From") {
                        Picker("Template", selection: templateSelection) {
                            Text("Blank Quest").tag(Optional<QuestTemplate>.none)
                            ForEach(templates) { template in
                                Text(template.name).tag(Optional(template))
                            }
                        }
                        Text("Starting from: \(selectedTemplate?.name ?? "Blank Quest")")
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Label(scheduleHint, systemImage: scheduleIcon)
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Schedule Quest")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createQuest)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var templateSelection: Binding<QuestTemplate?> {
        Binding(
            get: { nil },
            set: { template in
                if let template {
                    selectedTemplate = template
                    name = template.name
                }
            }
        )
    }

    private var scheduledStatus: QuestStatus { QuestScheduler.status(for: date) }

    private var scheduleHint: String {
        scheduledStatus == .planned
            ? "Scheduled for a future day. You can still edit it any time before then."
            : "Ready to log right away."
    }

    private var scheduleIcon: String {
        scheduledStatus == .planned ? "hourglass" : "flame.fill"
    }

    private func createQuest() {
        let quest: Quest
        if let selectedTemplate {
            quest = QuestTemplateService.makeQuest(from: selectedTemplate)
            quest.name = name
        } else {
            quest = Quest(name: name)
        }
        quest.date = date
        quest.status = scheduledStatus
        modelContext.insert(quest)
        onCreate(quest)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        QuestListView()
    }
    .modelContainer(PersistenceController.previewContainer)
}
