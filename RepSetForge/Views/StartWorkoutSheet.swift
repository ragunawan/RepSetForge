import SwiftUI
import SwiftData

/// Quick-start (name only) or start from a saved routine, which pre-populates
/// `SessionExercise`s and empty `SetEntry`s from the routine's target sets
/// (dev spec §1). The Recommended-next-routine suggestion on Home is still
/// TODO.md work — this is a plain picker, not a ranked recommendation.
struct StartWorkoutSheet: View {
    let onStart: (WorkoutSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.name) private var routines: [Routine]
    @State private var name = "Workout"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout name", text: $name)
                    Button("Start empty workout") { startEmpty() }
                }

                if !routines.isEmpty {
                    Section("Start from a routine") {
                        ForEach(routines) { routine in
                            Button {
                                startFromRoutine(routine)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                                    Text("\(routine.items.count) exercise\(routine.items.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Start workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func startEmpty() {
        let session = WorkoutSession(name: name)
        modelContext.insert(session)
        onStart(session)
        dismiss()
    }

    private func startFromRoutine(_ routine: Routine) {
        let session = WorkoutSession(name: routine.name, routine: routine)
        modelContext.insert(session)

        for item in routine.items.sorted(by: { $0.order < $1.order }) {
            let sessionExercise = SessionExercise(exercise: item.exercise, order: item.order)
            sessionExercise.routineItem = item
            sessionExercise.session = session
            modelContext.insert(sessionExercise)

            for setIndex in 0..<max(1, item.targetSets) {
                let set = SetEntry(index: setIndex)
                set.sessionExercise = sessionExercise
                modelContext.insert(set)
            }
        }

        onStart(session)
        dismiss()
    }
}
