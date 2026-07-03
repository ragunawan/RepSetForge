import SwiftUI
import SwiftData

struct ExerciseLoggingView: View {
    @Bindable var exercise: Exercise
    var isReadOnly: Bool = false

    @Environment(\.modelContext) private var modelContext

    private var sortedSets: [ExerciseSet] {
        exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
    }

    var body: some View {
        Form {
            skillSection
            setsSection
        }
        .navigationTitle(exercise.name)
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
                ExerciseSetRow(set: set, isReadOnly: isReadOnly)
            }
        } else {
            ForEach(sortedSets) { set in
                ExerciseSetRow(set: set, isReadOnly: isReadOnly)
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

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(RepSetForgeFont.stat(13))
                .frame(width: 56, alignment: .leading)

            repsAndWeight

            Button {
                set.completed.toggle()
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
