import SwiftUI
import SwiftData

struct ExerciseLoggingView: View {
    @Bindable var exercise: Exercise
    var isReadOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @State private var restSecondsRemaining: Int?
    @State private var showingMetrics = false

    private var sortedSets: [ExerciseSet] {
        exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
    }

    private var preferredWeightUnit: WeightUnit { characters.first?.preferredWeightUnit ?? .pounds }

    var body: some View {
        Form {
            skillSection
            if let restSecondsRemaining {
                restTimerSection(restSecondsRemaining)
            }
            setsSection
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingMetrics = true
                } label: {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
            }
        }
        .sheet(isPresented: $showingMetrics) {
            NavigationStack {
                ExerciseMetricsView(exerciseName: exercise.name)
            }
        }
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
            LabeledContent("Type", value: exercise.exerciseType.displayName)
            LabeledContent("Primary Muscle", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                LabeledContent("Secondary", value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))
            }
            notesField
            // Perceived effort is a post-workout reflection, not factual
            // workout content, so it stays editable even when isReadOnly.
            PerceivedEffortPicker(effort: $exercise.perceivedEffort)
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
                ExerciseSetRow(set: set, exerciseType: exercise.exerciseType, isReadOnly: isReadOnly, onComplete: {})
            }
        } else {
            ForEach(sortedSets) { set in
                ExerciseSetRow(set: set, exerciseType: exercise.exerciseType, isReadOnly: isReadOnly) {
                    let restSeconds = exercise.defaultRestSeconds
                    restSecondsRemaining = restSeconds > 0 ? restSeconds : nil
                    updateLiveActivity(restSeconds: restSeconds)
                }
            }
            .onDelete(perform: deleteSets)
        }
    }

    /// Starts (on the first set of the quest) or updates the Live Activity
    /// showing overall progress across every skill in the quest, not just
    /// this one — `exercise.quest` (the inverse relationship) is how a
    /// single exercise's logging view reaches the quest-wide totals.
    private func updateLiveActivity(restSeconds: Int) {
        guard let quest = exercise.quest else { return }
        let allSets = quest.exercises.flatMap(\.sets)
        let restEndDate = restSeconds > 0 ? Date.now.addingTimeInterval(TimeInterval(restSeconds)) : nil
        Task {
            await LiveActivityService.startOrUpdate(
                questName: quest.name,
                completedSetCount: allSets.filter(\.completed).count,
                totalSetCount: allSets.count,
                restEndDate: restEndDate
            )
        }
    }

    private func addSet() {
        let nextNumber = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        exercise.sets.append(ExerciseSet(setNumber: nextNumber, weightUnit: preferredWeightUnit))
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
    var exerciseType: ExerciseType
    var isReadOnly: Bool
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(RepSetForgeFont.stat(13))
                .frame(width: 56, alignment: .leading)

            setFields

            Button {
                set.completed.toggle()
                if set.completed {
                    onComplete()
                }
            } label: {
                let icon = Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.completed ? Color.questGreen : Color.secondary)
                // A quick, native "pop" on completion — skipped under Reduce
                // Motion since symbolEffect doesn't auto-disable itself.
                if reduceMotion {
                    icon.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                } else {
                    icon.symbolEffect(.bounce, value: set.completed)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .accessibilityLabel("Set \(set.setNumber)")
            .accessibilityValue(set.completed ? "Complete" : "Not complete")
            // A light tick, not a strong buzz — this fires often (every set,
            // every workout) so it should never fatigue the way a bigger
            // celebratory haptic would.
            .sensoryFeedback(.selection, trigger: set.completed) { _, isNowComplete in
                isNowComplete
            }
        }
    }

    @ViewBuilder
    private var setFields: some View {
        if exerciseType.tracksReps {
            repsField
        }
        if exerciseType.tracksWeight {
            weightField
        }
        if exerciseType.tracksDistance {
            distanceField
        }
        if exerciseType.tracksDuration {
            durationField
        }
    }

    @ViewBuilder
    private var repsField: some View {
        if isReadOnly {
            Text("\(set.reps) reps")
        } else {
            Stepper("\(set.reps) reps", value: $set.reps, in: 0...100)
        }
    }

    @ViewBuilder
    private var weightField: some View {
        if isReadOnly {
            Spacer()
            Text(set.weightUnit.formatted(set.weight))
        } else {
            TextField(exerciseType == .assisted ? "Assist" : "Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 64)
                .multilineTextAlignment(.trailing)
            Text(set.weightUnit.abbreviation)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var distanceField: some View {
        if isReadOnly {
            Spacer()
            Text("\(set.distanceMiles, specifier: "%.2f") mi")
        } else {
            TextField("Distance", value: $set.distanceMiles, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 64)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var durationField: some View {
        if isReadOnly {
            Spacer()
            Text(formattedDuration(set.durationSeconds))
        } else {
            Stepper(formattedDuration(set.durationSeconds), value: $set.durationSeconds, in: 0...3600, step: 5)
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    NavigationStack {
        ExerciseLoggingView(exercise: Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.arms]))
    }
    .modelContainer(PersistenceController.previewContainer)
}
