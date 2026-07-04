import SwiftUI
import SwiftData

struct QuestDetailView: View {
    @Bindable var quest: Quest

    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]
    @Query private var encounterStates: [RPGEncounterState]

    @State private var showingAddExercise = false
    @State private var showingSaveAsTemplate = false
    @State private var showingUndoConfirmation = false
    @State private var completionSummary: QuestCompletionSummary?

    private var isReadOnly: Bool { quest.status == .completed }

    var body: some View {
        Form {
            questSection
            skillsSection
            footerSection
        }
        .navigationTitle(isReadOnly ? "Quest" : "Edit Quest")
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingSaveAsTemplate = true
                    } label: {
                        Label("Save as Template", systemImage: "square.and.arrow.down")
                    }
                    .disabled(quest.exercises.isEmpty)
                }
            } else {
                ToolbarItem(placement: .secondaryAction) {
                    Button(role: .destructive) {
                        showingUndoConfirmation = true
                    } label: {
                        Label("Undo Completion", systemImage: "arrow.uturn.backward.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet(quest: quest)
        }
        .sheet(isPresented: $showingSaveAsTemplate) {
            SaveQuestTemplateSheet(quest: quest)
        }
        .sheet(item: $completionSummary) { summary in
            QuestCompletionView(summary: summary)
        }
        .confirmationDialog(
            "Undo Quest Completion?",
            isPresented: $showingUndoConfirmation,
            titleVisibility: .visible
        ) {
            Button("Undo Completion", role: .destructive) {
                undoCompletion()
            }
        } message: {
            Text("This reverts the quest to active and recalculates XP, levels, and achievements from your remaining completed quests.")
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

        // Notes and perceived effort are a post-workout reflection, not
        // factual workout content, so they stay editable even after
        // completion — unlike name/date/sets, which lock once isReadOnly.
        Section("Journal") {
            TextField("How did this session go?", text: $quest.notes, axis: .vertical)
            PerceivedEffortPicker(effort: $quest.perceivedEffort)
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
                    .font(RepSetForgeFont.heading(15))
                Text(exercise.primaryMuscle.displayName)
                    .font(RepSetForgeFont.body(12))
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
        let newRecords = PersonalRecordService.evaluateRecords(for: quest.exercises, context: modelContext)

        let completedSetCount = quest.exercises.reduce(0) { $0 + $1.completedSets.count }
        let earnedGold = GoldService.totalGold(completedSetCount: completedSetCount, questXP: xp, newRecordCount: newRecords.count)
        character.gold += earnedGold

        SkillProgressionService.distributeSkillXP(
            exercises: quest.exercises,
            prExerciseNames: Set(newRecords.map(\.exerciseName)),
            context: modelContext
        )

        character.totalPRCount += newRecords.count
        let rpgClass = encounterStates.first?.rpgClass ?? .knight
        var equipmentDrops: [EquipmentDropService.DropResult] = []
        if let drop = EquipmentDropService.checkQuestMilestone(completedQuestCount: character.completedQuestCount, rpgClass: rpgClass, context: modelContext) {
            equipmentDrops.append(drop)
        }
        if let drop = EquipmentDropService.checkPRMilestone(totalPRCount: character.totalPRCount, rpgClass: rpgClass, context: modelContext) {
            equipmentDrops.append(drop)
        }

        try? modelContext.save()

        completionSummary = QuestCompletionSummary(
            questName: quest.name,
            distribution: distribution,
            unlockedAchievements: unlocked,
            newRecords: newRecords,
            goldEarned: earnedGold,
            equipmentDrops: equipmentDrops
        )
    }

    private func undoCompletion() {
        quest.status = .active
        quest.completedDate = nil
        quest.totalXP = 0
        ProgressionRebuildService.rebuild(context: modelContext)
        try? modelContext.save()
    }
}

private struct AddExerciseSheet: View {
    let quest: Quest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]
    @Query private var characters: [PlayerCharacter]
    @Query private var allExercises: [Exercise]

    private var preferredWeightUnit: WeightUnit { characters.first?.preferredWeightUnit ?? .pounds }

    private var nameSuggestions: [String] {
        ExerciseNameSuggestionService.suggestions(matching: name, exerciseNames: allExercises.map(\.name))
    }

    @State private var name = ""
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var notes = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var defaultSetCount = 0
    @State private var defaultReps = 10
    @State private var defaultWeight: Double = 0
    @State private var defaultRestSeconds = 60
    @State private var defaultDistanceMiles: Double = 0
    @State private var defaultDurationSeconds = 60
    @State private var saveAsTemplate = false
    @State private var showingManageTemplates = false
    @State private var showingMetrics = false
    @State private var metricsExerciseName = ""

    var body: some View {
        NavigationStack {
            Form {
                if !templates.isEmpty {
                    templateSection
                }
                primarySection
                secondarySection
                setSchemeSection
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
            .sheet(isPresented: $showingManageTemplates) {
                ManageTemplatesSheet()
            }
            .sheet(isPresented: $showingMetrics) {
                NavigationStack {
                    ExerciseMetricsView(exerciseName: metricsExerciseName)
                }
            }
        }
    }

    private var templateSection: some View {
        Section("Templates") {
            Picker("Load Template", selection: templateSelection) {
                Text("None").tag(Optional<ExerciseTemplate>.none)
                ForEach(templates) { template in
                    Text(template.name).tag(Optional(template))
                }
            }
            Button("Manage Templates") { showingManageTemplates = true }
        }
    }

    private var templateSelection: Binding<ExerciseTemplate?> {
        Binding(
            get: { nil },
            set: { template in
                if let template { applyTemplate(template) }
            }
        )
    }

    private var primarySection: some View {
        Section("Skill") {
            TextField("Name", text: $name)
            if !nameSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RepSetForgeMetrics.paddingSmall) {
                        ForEach(nameSuggestions, id: \.self) { suggestion in
                            HStack(spacing: 4) {
                                Button(suggestion) { name = suggestion }
                                Button {
                                    metricsExerciseName = suggestion
                                    showingMetrics = true
                                } label: {
                                    Image(systemName: "chart.xyaxis.line")
                                }
                            }
                            .font(RepSetForgeFont.body(12))
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, RepSetForgeMetrics.paddingSmall)
            }
            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
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

    @ViewBuilder
    private var setSchemeSection: some View {
        Section("Default Set Scheme") {
            Stepper("Sets: \(defaultSetCount)", value: $defaultSetCount, in: 0...10)
            if exerciseType.tracksReps {
                Stepper("Reps: \(defaultReps)", value: $defaultReps, in: 0...50)
            }
            if exerciseType.tracksWeight {
                HStack {
                    Text(exerciseType == .assisted ? "Assist Weight" : "Weight")
                    Spacer()
                    TextField("Weight", value: $defaultWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text(preferredWeightUnit.abbreviation)
                        .foregroundStyle(.secondary)
                }
            }
            if exerciseType.tracksDistance {
                HStack {
                    Text("Distance (mi)")
                    Spacer()
                    TextField("Distance", value: $defaultDistanceMiles, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                }
            }
            if exerciseType.tracksDuration {
                Stepper("Duration: \(formattedDuration(defaultDurationSeconds))", value: $defaultDurationSeconds, in: 0...3600, step: 15)
            }
            Stepper("Rest: \(defaultRestSeconds)s", value: $defaultRestSeconds, in: 0...300, step: 15)
            Toggle("Save as Template", isOn: $saveAsTemplate)
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func secondaryBinding(for group: MuscleGroup) -> Binding<Bool> {
        Binding(
            get: { secondaryMuscles.contains(group) },
            set: { isOn in
                if isOn { secondaryMuscles.insert(group) } else { secondaryMuscles.remove(group) }
            }
        )
    }

    private func applyTemplate(_ template: ExerciseTemplate) {
        name = template.name
        primaryMuscle = template.primaryMuscle
        secondaryMuscles = Set(template.secondaryMuscles)
        notes = template.notes
        exerciseType = template.exerciseType
        defaultSetCount = template.defaultSetCount
        defaultReps = template.defaultReps
        defaultWeight = template.defaultWeight
        defaultRestSeconds = template.defaultRestSeconds
        defaultDistanceMiles = template.defaultDistanceMiles
        defaultDurationSeconds = template.defaultDurationSeconds
    }

    private func addExercise() {
        let exercise = ExerciseTemplateService.makeExercise(
            from: ExerciseTemplateService.makeTemplate(
                name: name.isEmpty ? "New Skill" : name,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: Array(secondaryMuscles),
                notes: notes,
                defaultSetCount: defaultSetCount,
                defaultReps: defaultReps,
                defaultWeight: defaultWeight,
                defaultRestSeconds: defaultRestSeconds,
                exerciseType: exerciseType,
                defaultDistanceMiles: defaultDistanceMiles,
                defaultDurationSeconds: defaultDurationSeconds
            ),
            unit: preferredWeightUnit
        )
        quest.exercises.append(exercise)

        if saveAsTemplate {
            let template = ExerciseTemplateService.makeTemplate(
                name: exercise.name,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: Array(secondaryMuscles),
                notes: notes,
                defaultSetCount: defaultSetCount,
                defaultReps: defaultReps,
                defaultWeight: defaultWeight,
                defaultRestSeconds: defaultRestSeconds,
                exerciseType: exerciseType,
                defaultDistanceMiles: defaultDistanceMiles,
                defaultDurationSeconds: defaultDurationSeconds
            )
            modelContext.insert(template)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct ManageTemplatesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if templates.isEmpty {
                        Text("No saved templates yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates) { template in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(RepSetForgeFont.heading(15))
                                Text("\(template.primaryMuscle.displayName) · \(template.defaultSetCount) × \(template.defaultReps)")
                                    .font(RepSetForgeFont.body(12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }
            }
            .navigationTitle("Manage Templates")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }
}

private struct SaveQuestTemplateSheet: View {
    let quest: Quest

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(quest: Quest) {
        self.quest = quest
        _name = State(initialValue: quest.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("Name", text: $name)
                }
                Section {
                    Text("Saves \(quest.exercises.count == 1 ? "1 skill" : "\(quest.exercises.count) skills") with their current set schemes.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Save as Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTemplate)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveTemplate() {
        let template = QuestTemplateService.makeTemplate(name: name, exercises: quest.exercises)
        modelContext.insert(template)
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
