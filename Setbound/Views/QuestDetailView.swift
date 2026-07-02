import SwiftUI
import SwiftData

struct QuestDetailView: View {
    @Bindable var quest: Quest

    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]

    @State private var showingAddExercise = false
    @State private var completionSummary: QuestCompletionSummary?

    private var isReadOnly: Bool { quest.status == .completed }

    var body: some View {
        Form {
            questSection
            skillsSection
            footerSection
        }
        .navigationTitle(isReadOnly ? "Quest" : "Edit Quest")
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet(quest: quest)
        }
        .sheet(item: $completionSummary) { summary in
            QuestCompletionView(summary: summary)
        }
    }

    @ViewBuilder
    private var questSection: some View {
        Section("Quest") {
            if isReadOnly {
                LabeledContent("Name", value: quest.name)
                LabeledContent("Date", value: quest.date.formatted(date: .abbreviated, time: .omitted))
            } else {
                TextField("Quest Name", text: $quest.name)
                DatePicker("Date", selection: $quest.date, displayedComponents: .date)
            }
        }
    }

    @ViewBuilder
    private var skillsSection: some View {
        Section("Skills") {
            exerciseRows
            if !isReadOnly {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Skill", systemImage: "plus.circle.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseRows: some View {
        if isReadOnly {
            ForEach(quest.exercises) { exercise in
                exerciseRow(exercise)
            }
        } else {
            ForEach(quest.exercises) { exercise in
                exerciseRow(exercise)
            }
            .onDelete(perform: deleteExercises)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        NavigationLink {
            ExerciseLoggingView(exercise: exercise, isReadOnly: isReadOnly)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(SetboundFont.heading(15))
                Text(exercise.primaryMuscle.displayName)
                    .font(SetboundFont.body(12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        if !isReadOnly {
            Section {
                Button("Complete Quest") {
                    completeQuest()
                }
                .disabled(quest.exercises.isEmpty)
            }
        } else if quest.totalXP > 0 {
            Section("Reward") {
                LabeledContent("Total XP", value: "+\(quest.totalXP)")
            }
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(quest.exercises[index])
        }
    }

    private func completeQuest() {
        guard let character = characters.first else { return }

        let xp = ProgressionService.questXP(exercises: quest.exercises)
        let distribution = ProgressionService.distributeXP(
            questXP: xp,
            exercises: quest.exercises,
            to: character,
            and: muscles
        )

        quest.status = .completed
        quest.completedDate = .now
        quest.totalXP = xp
        character.completedQuestCount += 1

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: modelContext)
        try? modelContext.save()

        completionSummary = QuestCompletionSummary(
            questName: quest.name,
            distribution: distribution,
            unlockedAchievements: unlocked
        )
    }
}

private struct AddExerciseSheet: View {
    let quest: Quest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                primarySection
                secondarySection
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add Skill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addExercise)
                }
            }
        }
    }

    private var primarySection: some View {
        Section("Skill") {
            TextField("Name", text: $name)
            Picker("Primary Muscle", selection: $primaryMuscle) {
                ForEach(MuscleGroup.allCases) { group in
                    Text(group.displayName).tag(group)
                }
            }
        }
    }

    private var secondarySection: some View {
        Section("Secondary Muscles") {
            ForEach(MuscleGroup.allCases.filter { $0 != primaryMuscle }) { group in
                Toggle(group.displayName, isOn: secondaryBinding(for: group))
            }
        }
    }

    private func secondaryBinding(for group: MuscleGroup) -> Binding<Bool> {
        Binding(
            get: { secondaryMuscles.contains(group) },
            set: { isOn in
                if isOn { secondaryMuscles.insert(group) } else { secondaryMuscles.remove(group) }
            }
        )
    }

    private func addExercise() {
        let exercise = Exercise(
            name: name.isEmpty ? "New Skill" : name,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: Array(secondaryMuscles),
            notes: notes
        )
        quest.exercises.append(exercise)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        QuestDetailView(quest: Quest(name: "Preview Quest", status: .active))
    }
    .modelContainer(PersistenceController.previewContainer)
}
