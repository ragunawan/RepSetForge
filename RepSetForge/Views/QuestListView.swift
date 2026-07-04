import SwiftUI
import SwiftData

struct QuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]
    @Query(sort: \QuestTemplate.name) private var questTemplates: [QuestTemplate]
    @Query private var characters: [PlayerCharacter]

    @State private var newQuest: Quest?
    @State private var showingManageQuestTemplates = false
    @State private var showingScheduleQuest = false
    @State private var showingFilters = false
    @State private var filterCriteria = QuestFilterCriteria()

    private var quests: [Quest] { allQuests.filter { $0.status != .completed } }
    private var preferredWeightUnit: WeightUnit { characters.first?.preferredWeightUnit ?? .pounds }

    /// While no search/filter is active, keep the original default of
    /// non-completed quests only. Once a filter is active — including a
    /// status filter — search across every quest, since "status" is one of
    /// the filterable dimensions and would otherwise be meaningless.
    private var displayedQuests: [Quest] {
        filterCriteria.isActive ? QuestFilterService.filter(allQuests, criteria: filterCriteria) : quests
    }

    var body: some View {
        List {
            ForEach(displayedQuests) { quest in
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
        .searchable(text: $filterCriteria.searchText, prompt: "Search quests or skills")
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
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingFilters = true
                } label: {
                    Label("Filters", systemImage: filterCriteria.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingManageQuestTemplates) {
            ManageQuestTemplatesSheet()
        }
        .sheet(isPresented: $showingScheduleQuest) {
            ScheduleQuestSheet(weightUnit: preferredWeightUnit) { quest in
                newQuest = quest
            }
        }
        .sheet(isPresented: $showingFilters) {
            QuestFilterSheet(criteria: $filterCriteria)
        }
        .overlay {
            if displayedQuests.isEmpty {
                Text(filterCriteria.isActive ? "No quests match your filters." : "No quests yet. Tap + to start one.")
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
        let quest = QuestTemplateService.makeQuest(from: template, unit: preferredWeightUnit)
        modelContext.insert(quest)
        newQuest = quest
    }

    private func deleteQuests(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(displayedQuests[index])
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
                            .font(RepSetForgeFont.body(13))
                            .foregroundStyle(Color.questNavy.opacity(0.6))
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

    let weightUnit: WeightUnit
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
            quest = QuestTemplateService.makeQuest(from: selectedTemplate, unit: weightUnit)
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

private struct QuestFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var criteria: QuestFilterCriteria

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $criteria.status) {
                        Text("Any").tag(QuestStatus?.none)
                        ForEach(QuestStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(Optional(status))
                        }
                    }
                }
                Section("Muscle Group") {
                    Picker("Muscle Group", selection: $criteria.muscleGroup) {
                        Text("Any").tag(MuscleGroup?.none)
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(Optional(group))
                        }
                    }
                }
                Section("Date Range") {
                    optionalDateRow(label: "After", date: $criteria.startDate)
                    optionalDateRow(label: "Before", date: $criteria.endDate)
                }
                Section("XP Range") {
                    optionalXPRow(label: "Minimum XP", value: $criteria.minXP)
                    optionalXPRow(label: "Maximum XP", value: $criteria.maxXP)
                }
                if criteria.isActive {
                    Section {
                        Button("Clear Filters", role: .destructive) {
                            let searchText = criteria.searchText
                            criteria = QuestFilterCriteria(searchText: searchText)
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func optionalDateRow(label: String, date: Binding<Date?>) -> some View {
        Toggle(label, isOn: Binding(
            get: { date.wrappedValue != nil },
            set: { enabled in date.wrappedValue = enabled ? .now : nil }
        ))
        if let unwrapped = date.wrappedValue {
            DatePicker(label, selection: Binding(
                get: { unwrapped },
                set: { date.wrappedValue = $0 }
            ), displayedComponents: .date)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func optionalXPRow(label: String, value: Binding<Int?>) -> some View {
        Toggle(label, isOn: Binding(
            get: { value.wrappedValue != nil },
            set: { enabled in value.wrappedValue = enabled ? 0 : nil }
        ))
        if let unwrapped = value.wrappedValue {
            Stepper("\(unwrapped) XP", value: Binding(
                get: { unwrapped },
                set: { value.wrappedValue = $0 }
            ), in: 0...100_000, step: 50)
        }
    }
}

#Preview {
    NavigationStack {
        QuestListView()
    }
    .modelContainer(PersistenceController.previewContainer)
}
