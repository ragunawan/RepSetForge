import SwiftUI
import SwiftData

struct ExerciseLoggingView: View {
    @Bindable var exercise: Exercise
    var isReadOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    @State private var restSecondsRemaining: Int?

    private var sortedSets: [ExerciseSet] {
        exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
    }

    var body: some View {
        Form {
            skillSection
            if let restSecondsRemaining {
                restTimerSection(restSecondsRemaining)
            }
            setsSection
        }
        .navigationTitle(exercise.name)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let remaining = restSecondsRemaining else { return }
            restSecondsRemaining = remaining > 1 ? remaining - 1 : nil
        }
    }

    @ViewBuilder
    private var skillSection: some View {
        Section("Skill") {
            if isReadOnly {
                LabeledContent("Name", value: exercise.name)
            } else {
                TextField("Name", text: $exercise.name)
            }
            LabeledContent("Primary Muscle", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                LabeledContent("Secondary", value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))
            }
            notesField
            if isReadOnly {
                LabeledContent("Rest", value: "\(exercise.defaultRestSeconds)s")
            } else {
                Stepper("Rest: \(exercise.defaultRestSeconds)s", value: $exercise.defaultRestSeconds, in: 0...300, step: 15)
            }
        }
    }

    @ViewBuilder
    private func restTimerSection(_ secondsRemaining: Int) -> some View {
        Section {
            HStack {
                Label("Resting: \(secondsRemaining)s", systemImage: "hourglass")
                    .font(RepSetForgeFont.heading(15))
                    .foregroundStyle(Color.questGold)
                Spacer()
                Button("Skip") {
                    restSecondsRemaining = nil
                }
                .font(RepSetForgeFont.body(13))
            }
        }
    }

    @ViewBuilder
    private var notesField: some View {
        if isReadOnly {
            if !exercise.notes.isEmpty {
                Text(exercise.notes)
            }
        } else {
            TextField("Notes", text: $exercise.notes, axis: .vertical)
        }
    }

    @ViewBuilder
    private var setsSection: some View {
        Section("Sets") {
            setRows
            if !isReadOnly {
                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var setRows: some View {
        if isReadOnly {
            ForEach(sortedSets) { set in
                ExerciseSetRow(set: set, isReadOnly: isReadOnly, onComplete: {})
            }
        } else {
            ForEach(sortedSets) { set in
                ExerciseSetRow(set: set, isReadOnly: isReadOnly) {
                    restSecondsRemaining = exercise.defaultRestSeconds > 0 ? exercise.defaultRestSeconds : nil
                }
            }
            .onDelete(perform: deleteSets)
        }
    }

    private func addSet() {
        let nextNumber = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        exercise.sets.append(ExerciseSet(setNumber: nextNumber))
    }

    private func deleteSets(at offsets: IndexSet) {
        let sorted = sortedSets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

private struct ExerciseSetRow: View {
    @Bindable var set: ExerciseSet
    var isReadOnly: Bool
    var onComplete: () -> Void

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(RepSetForgeFont.stat(13))
                .frame(width: 56, alignment: .leading)

            repsAndWeight

            Button {
                set.completed.toggle()
                if set.completed {
                    onComplete()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.completed ? Color.questGreen : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
        }
    }

    @ViewBuilder
    private var repsAndWeight: some View {
        if isReadOnly {
            Text("\(set.reps) reps")
            Spacer()
            Text("\(set.weight, specifier: "%.1f") lb")
        } else {
            Stepper("\(set.reps) reps", value: $set.reps, in: 0...100)
            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 64)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLoggingView(exercise: Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.arms]))
    }
    .modelContainer(PersistenceController.previewContainer)
}
