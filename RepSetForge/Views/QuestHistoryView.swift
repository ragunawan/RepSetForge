import SwiftUI
import SwiftData

private enum HistoryDisplayMode: String, CaseIterable {
    case list = "List"
    case calendar = "Calendar"
    case charts = "Charts"
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
                case .charts:
                    ScrollView {
                        TrainingChartsView(quests: completedQuests)
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
                    .frame(width: 260)
                }
            }
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest)
            }
            .navigationDestination(item: $duplicatedQuest) { quest in
                QuestDetailView(quest: quest)
            }
            .overlay {
                // Calendar mode is left alone here: its month grid is still
                // useful to browse even with no history, and it already
                // explains "no quests" per selected day at the row level —
                // an overlay on top would just visually collide with the grid.
                if completedQuests.isEmpty, displayMode != .calendar {
                    emptyStateMessage
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateMessage: some View {
        VStack(spacing: 4) {
            Text("No completed quests yet.")
                .font(RepSetForgeFont.body())
                .foregroundStyle(Color.questNavy.opacity(0.6))
            if displayMode == .charts {
                Text("Charts fill in once you complete your first quest.")
                    .font(RepSetForgeFont.body(12))
                    .foregroundStyle(Color.questNavy.opacity(0.5))
            }
        }
        .multilineTextAlignment(.center)
        .padding(RepSetForgeMetrics.paddingLarge)
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

#Preview("Empty — no completed quests") {
    QuestHistoryView()
        .modelContainer(PersistenceController.previewContainer)
}

private func historyPreviewContainer() -> ModelContainer {
    let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)
    let calendar = Calendar.current
    for daysAgo in [0, 1, 3, 7] {
        let quest = Quest(name: "Push Day", status: .completed)
        quest.completedDate = calendar.date(byAdding: .day, value: -daysAgo, to: .now)
        quest.totalXP = 180
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 8, weight: 135, completed: true)]
        quest.exercises = [exercise]
        context.insert(quest)
    }
    return container
}

#Preview("Populated") {
    QuestHistoryView()
        .modelContainer(historyPreviewContainer())
}
