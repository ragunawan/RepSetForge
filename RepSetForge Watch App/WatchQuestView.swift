import SwiftUI
import SwiftData

/// Root screen: the current (non-completed) quest's skills, or an empty
/// state if nothing has synced down yet or there's no active quest.
struct WatchQuestView: View {
    @Query(sort: \Quest.date, order: .reverse) private var allQuests: [Quest]

    private var currentQuest: Quest? {
        allQuests.first { $0.status != .completed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let quest = currentQuest {
                    List(quest.exercises) { exercise in
                        NavigationLink(exercise.name) {
                            WatchExerciseView(exercise: exercise)
                        }
                    }
                    .navigationTitle(quest.name)
                } else {
                    ContentUnavailableView(
                        "No Active Quest",
                        systemImage: "shield.lefthalf.filled",
                        description: Text("Start a quest on your phone to log sets here.")
                    )
                }
            }
        }
    }
}

#Preview("No active quest") {
    WatchQuestView()
        .modelContainer(Fixtures.makeContainer())
}

private func activeQuestPreviewContainer() -> ModelContainer {
    let container = Fixtures.makeContainer()
    let context = ModelContext(container)
    let exercise = Fixtures.makeExercise(sets: [(8, 135, false), (8, 135, false)])
    let quest = Fixtures.makeQuest(status: .active, exercises: [exercise])
    context.insert(quest)
    return container
}

#Preview("Active quest") {
    WatchQuestView()
        .modelContainer(activeQuestPreviewContainer())
}
