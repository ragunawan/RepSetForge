import SwiftData
import SwiftUI

struct StartWorkoutSheet: View {
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    let start: (WorkoutSession) -> Void
    @State private var showingPicker = false
    @State private var adHocExercises: [Exercise] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Recommended") {
                    ForEach(routines) { routine in
                        Button {
                            start(makeSession(from: routine))
                        } label: {
                            VStack(alignment: .leading) {
                                Text(routine.name)
                                Text("\((routine.orderedItems ?? []).count) exercises").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if routines.isEmpty {
                        Text("Create your first exercise or routine to start.")
                    }
                }
                Section("Quick start") {
                    ForEach(adHocExercises) { Text($0.name) }
                    Button(exercises.isEmpty ? "Create your first exercise" : "Add exercise") { showingPicker = true }
                    Button("Start empty workout") {
                        start(WorkoutSession(name: "Open Workout", exercises: adHocExercises.enumerated().map { SessionExercise(exercise: $0.element, order: $0.offset) }))
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar { Button("Cancel") { dismiss() } }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    adHocExercises.append(exercise)
                    showingPicker = false
                }
            }
        }
    }

    private func makeSession(from routine: Routine) -> WorkoutSession {
        let sessionExercises: [SessionExercise] = (routine.orderedItems ?? []).sorted { $0.order < $1.order }.enumerated().compactMap { offset, item in
            guard let exercise = exercises.first(where: { $0.id == item.exerciseID || $0.name == item.exerciseName }) else { return nil }
            let se = SessionExercise(exercise: exercise, order: offset, targetSets: item.targetSets, restSeconds: item.restSeconds)
            se.progressionRule = item.progressionRule
            return se
        }
        return WorkoutSession(name: routine.name, routineID: routine.id, exercises: sessionExercises)
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    let add: (Exercise) -> Void
    @State private var search = ""
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var expandedID: UUID?
    @State private var showingCreate = false

    var filtered: [Exercise] {
        exercises.filter { exercise in
            let text = search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search)
            let muscle = selectedMuscles.isEmpty || selectedMuscles.contains(exercise.primaryMuscle)
            let equipment = selectedEquipment.isEmpty || selectedEquipment.contains(exercise.equipment)
            return text && muscle && equipment
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(MuscleGroup.allCases) { muscle in
                                Button { toggle(muscle) } label: { RSChip(text: muscle.title, selected: selectedMuscles.contains(muscle)) }
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Equipment.allCases) { equipment in
                                Button { toggle(equipment) } label: { RSChip(text: equipment.title, selected: selectedEquipment.contains(equipment)) }
                            }
                        }
                    }
                }
                if exercises.isEmpty {
                    Section { Button("Create your first exercise") { showingCreate = true } }
                } else {
                    Section("All") {
                        ForEach(filtered) { exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    expandedID = expandedID == exercise.id ? nil : exercise.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(exercise.name)
                                            Text("\(exercise.primaryMuscle.title) · \(exercise.equipment.title)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: expandedID == exercise.id ? "chevron.up" : "chevron.down")
                                    }
                                }
                                if expandedID == exercise.id {
                                    MiniBarChart(values: [0.2,0.25,0.4,0.35,0.6,0.75])
                                    Button("Add to workout") { add(exercise) }.buttonStyle(RSButtonStyle(kind: .primary))
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Exercise Selection")
            .toolbar {
                Button("New") { showingCreate = true }
                Button("Close") { dismiss() }
            }
            .sheet(isPresented: $showingCreate) { CreateExerciseView() }
        }
    }

    private func toggle(_ muscle: MuscleGroup) {
        if selectedMuscles.contains(muscle) { selectedMuscles.remove(muscle) } else { selectedMuscles.insert(muscle) }
    }
    private func toggle(_ equipment: Equipment) {
        if selectedEquipment.contains(equipment) { selectedEquipment.remove(equipment) } else { selectedEquipment.insert(equipment) }
    }
}

struct CreateExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var name = ""
    @State private var primary: MuscleGroup = .chest
    @State private var secondary: Set<MuscleGroup> = []
    @State private var equipment: Equipment = .barbell

    var similar: [Exercise] { exercises.filter { TrainingMath.namesAreSimilar(name, $0.name) } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    Picker("Primary muscle", selection: $primary) { ForEach(MuscleGroup.allCases) { Text($0.title).tag($0) } }
                    Picker("Equipment", selection: $equipment) { ForEach(Equipment.allCases) { Text($0.title).tag($0) } }
                }
                Section("Secondary muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.title, isOn: Binding(
                            get: { secondary.contains(muscle) },
                            set: { isOn in
                                if isOn {
                                    secondary.insert(muscle)
                                } else {
                                    secondary.remove(muscle)
                                }
                            }
                        ))
                    }
                }
                if !similar.isEmpty && !name.isEmpty {
                    Section("Similar exists") {
                        ForEach(similar) { Text($0.name) }
                    }
                }
            }
            .navigationTitle("Create Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }

    private func save() {
        context.insert(Exercise(name: name, primary: primary, secondary: Array(secondary), equipment: equipment))
        try? context.save()
        dismiss()
    }
}

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    let session: WorkoutSession
    let minimize: () -> Void
    @State private var page = 0
    @State private var showingIndex = false
    @State private var showingProgression = false
    @State private var confirmFinish = false
    @State private var shareSummary = ""
    @State private var replacingExercise: SessionExercise?

    var exercises: [SessionExercise] { (session.exercises ?? []).sorted { $0.order < $1.order } }
    var workoutPages: [WorkoutExercisePage] { WorkoutExercisePage.makePages(from: exercises) }
    var settings: AppSettings { settingsRows.first ?? AppSettings() }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TelemetryHeader(session: session)
                TabView(selection: $page) {
                    ForEach(Array(workoutPages.enumerated()), id: \.element.id) { index, workoutPage in
                        ExerciseFocusPage(
                            workoutPage: workoutPage,
                            exercises: exercises,
                            settings: settings,
                            moveUp: { move($0, by: -1) },
                            moveDown: { move($0, by: 1) },
                            supersetWithPrevious: supersetWithPrevious,
                            supersetWithNext: supersetWithNext,
                            ungroup: ungroup,
                            replace: { replacingExercise = $0 },
                            remove: remove
                        )
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .appBackground()

            VStack(spacing: 8) {
                if let rest = store.restTimer.state {
                    RestTimerPill(rest: rest, extend: { store.restTimer.extend() }, skip: { store.restTimer.skip() })
                        .padding(.horizontal)
                }
                BottomWorkoutPill(
                    pageText: pageText,
                    minimize: minimize,
                    progression: { showingProgression = true },
                    index: { showingIndex = true },
                    share: { shareSummary = "\(session.name): \(session.completedSetCount)/\(session.plannedSetCount) sets logged." },
                    finish: { confirmFinish = true }
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .onChange(of: workoutPages.count) { _, count in page = min(page, max(count - 1, 0)) }
        .sheet(isPresented: $showingIndex) { ExerciseIndexSheet(pages: workoutPages, selectedPage: $page) }
        .sheet(isPresented: $showingProgression) {
            if let exercise = workoutPages[safe: page]?.exercises.first { ProgressionPanelView(exercise: exercise) }
        }
        .sheet(item: $replacingExercise) { exercise in
            ExercisePickerView { replacement in
                replace(exercise, with: replacement)
                replacingExercise = nil
            }
        }
        .alert("Workout summary", isPresented: Binding(get: { !shareSummary.isEmpty }, set: { if !$0 { shareSummary = "" } })) {
            Button("Done", role: .cancel) { shareSummary = "" }
        } message: {
            Text(shareSummary)
        }
        .confirmationDialog("Finish workout?", isPresented: $confirmFinish) {
            Button("Finish workout") { store.finishActiveSession(context: context, bodyweightKg: bodyMetrics.first?.bodyweightKg) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(session.completedSetCount) of \(session.plannedSetCount) planned sets are complete.")
        }
    }

    private var pageText: String {
        guard let workoutPage = workoutPages[safe: page] else { return "0/0" }
        let prefix = workoutPage.isGroup ? "GROUP " : ""
        return "\(prefix)\(min(page + 1, max(workoutPages.count, 1)))/\(max(workoutPages.count, 1))"
    }

    private func move(_ exercise: SessionExercise, by offset: Int) {
        guard let current = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let destination = current + offset
        guard exercises.indices.contains(destination) else { return }
        exercises[current].order = destination
        exercises[destination].order = current
        renumberExercises()
    }

    private func supersetWithPrevious(_ exercise: SessionExercise) {
        guard let current = exercises.firstIndex(where: { $0.id == exercise.id }), current > 0 else { return }
        group(exercise, with: exercises[current - 1])
    }

    private func supersetWithNext(_ exercise: SessionExercise) {
        guard let current = exercises.firstIndex(where: { $0.id == exercise.id }), exercises.indices.contains(current + 1) else { return }
        group(exercise, with: exercises[current + 1])
    }

    private func group(_ exercise: SessionExercise, with other: SessionExercise) {
        let id = exercise.groupID ?? other.groupID ?? UUID()
        exercise.groupID = id
        other.groupID = id
        renumberExercises()
    }

    private func ungroup(_ exercise: SessionExercise) {
        exercise.groupID = nil
        renumberExercises()
    }

    private func replace(_ exercise: SessionExercise, with replacement: Exercise) {
        exercise.exerciseName = replacement.name
        exercise.exerciseID = replacement.id
        exercise.primaryMuscleRaw = replacement.primaryMuscle.rawValue
        exercise.muscleDetail = ([replacement.primaryMuscle.title] + replacement.secondaryMuscles.map(\.title)).joined(separator: " · ")
        try? context.save()
    }

    private func remove(_ exercise: SessionExercise) {
        guard exercise.completedSets == 0 else { return }
        session.exercises?.removeAll { $0.id == exercise.id }
        renumberExercises()
    }

    private func renumberExercises() {
        for (order, exercise) in exercises.enumerated() {
            exercise.order = order
        }
        try? context.save()
    }
}

struct TelemetryHeader: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SESSION: \(format(session.duration))").font(RSTheme.mono(11, weight: .semibold))
            Text("WORK: \(format(workSeconds))    REST: \(format(restSeconds))").font(RSTheme.mono(11, weight: .semibold))
            Text("\(progressPct)% DONE          SET \(session.completedSetCount)/\(session.plannedSetCount)").font(RSTheme.mono(11, weight: .semibold))
            ProgressView(value: Double(session.completedSetCount), total: Double(max(session.plannedSetCount, 1))).tint(RSTheme.signal)
        }
        .foregroundStyle(RSTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }
    private var progressPct: Int { Int(Double(session.completedSetCount) / Double(max(session.plannedSetCount, 1)) * 100) }
    private var restSeconds: TimeInterval {
        TimeInterval((session.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isCompleted).reduce(0) { $0 + $1.restSeconds })
    }
    private var workSeconds: TimeInterval { max(0, session.duration - restSeconds) }
    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }
}

struct WorkoutExercisePage: Identifiable {
    let id: String
    let groupID: UUID?
    let exercises: [SessionExercise]

    var isGroup: Bool { exercises.count > 1 }
    var title: String { isGroup ? "Superset \(exercises.count)" : (exercises.first?.exerciseName ?? "Exercise") }
    var subtitle: String {
        guard isGroup else { return exercises.first?.muscleDetail ?? "" }
        let sets = exercises.reduce(0) { $0 + $1.completedSets }
        let total = exercises.reduce(0) { $0 + $1.totalSets }
        return "\(sets)/\(total) sets · Rest after group"
    }
    var completedSets: Int { exercises.reduce(0) { $0 + $1.completedSets } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.totalSets } }

    static func makePages(from exercises: [SessionExercise]) -> [WorkoutExercisePage] {
        var pages: [WorkoutExercisePage] = []
        var index = 0
        while index < exercises.count {
            let exercise = exercises[index]
            if let groupID = exercise.groupID {
                var group: [SessionExercise] = []
                var scan = index
                while scan < exercises.count, exercises[scan].groupID == groupID {
                    group.append(exercises[scan])
                    scan += 1
                }
                if group.count > 1 {
                    pages.append(WorkoutExercisePage(id: "group-\(groupID.uuidString)", groupID: groupID, exercises: group))
                    index = scan
                    continue
                }
            }
            pages.append(WorkoutExercisePage(id: exercise.id.uuidString, groupID: nil, exercises: [exercise]))
            index += 1
        }
        return pages
    }
}

struct ExerciseFocusPage: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    let workoutPage: WorkoutExercisePage
    let exercises: [SessionExercise]
    let settings: AppSettings
    let moveUp: (SessionExercise) -> Void
    let moveDown: (SessionExercise) -> Void
    let supersetWithPrevious: (SessionExercise) -> Void
    let supersetWithNext: (SessionExercise) -> Void
    let ungroup: (SessionExercise) -> Void
    let replace: (SessionExercise) -> Void
    let remove: (SessionExercise) -> Void
    @State private var showingPlateCalcFor: SetEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pageHeader
                ForEach(workoutPage.exercises) { exercise in
                    exerciseSection(exercise)
                    if exercise.id != workoutPage.exercises.last?.id {
                        Divider().background(RSTheme.hairline)
                    }
                }
                Spacer(minLength: 110)
            }
        }
        .sheet(item: $showingPlateCalcFor) { set in
            PlateCalculatorView(set: set, settings: settings)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(text: workoutPage.isGroup ? "Superset group" : "Exercise")
                Spacer()
                Text(workoutPage.subtitle)
                    .font(RSTheme.mono(11, weight: .semibold))
                    .foregroundStyle(RSTheme.textSecondary)
            }
            if workoutPage.isGroup {
                Text(workoutPage.exercises.map(\.exerciseName).joined(separator: " + "))
                    .font(RSTheme.mono(15, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, workoutPage.isGroup ? 10 : 0)
    }

    private func exerciseSection(_ exercise: SessionExercise) -> some View {
        let sortedSets = (exercise.sets ?? []).sorted { $0.index < $1.index }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(icon(for: exercise))
                    .frame(width: 44, height: 44)
                    .background(RSTheme.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(RSTheme.hairline))
                VStack(alignment: .leading) {
                    if workoutPage.isGroup {
                        Text("Exercise \(groupPosition(for: exercise))").font(RSTheme.mono(11, weight: .semibold)).foregroundStyle(RSTheme.textSecondary)
                    }
                    Text(exercise.exerciseName).font(RSTheme.mono(19, weight: .bold))
                    Text(exercise.muscleDetail).font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                }
                Spacer()
                Menu {
                    Button("Move Up") { moveUp(exercise) }
                        .disabled(!canMove(exercise, by: -1))
                    Button("Move Down") { moveDown(exercise) }
                        .disabled(!canMove(exercise, by: 1))
                    Divider()
                    Button("Replace") { replace(exercise) }
                    if exercise.groupID == nil {
                        Button("Superset with Previous") { supersetWithPrevious(exercise) }
                            .disabled(!canGroup(exercise, by: -1))
                        Button("Superset with Next") { supersetWithNext(exercise) }
                            .disabled(!canGroup(exercise, by: 1))
                    } else {
                        Button("Ungroup") { ungroup(exercise) }
                    }
                    Divider()
                    Button("Remove", role: .destructive) { remove(exercise) }
                        .disabled(exercise.completedSets > 0)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Exercise actions")
            }
            .padding(14)
            Divider().background(RSTheme.hairline)

            if exercise.chartCollapsed {
                Button { exercise.chartCollapsed = false } label: {
                    HStack { Text("CHART · 1RM 128 · PR 102.5×8"); Spacer(); Image(systemName: "chevron.down") }
                        .font(RSTheme.mono(12, weight: .semibold))
                        .padding(12)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { RSChip(text: "3M", selected: true); RSChip(text: "%1RM") }
                    LineTrendChart(values: [0.3,0.4,0.36,0.62,0.7])
                    HStack { RSChip(text: "e1RM 174"); RSChip(text: "Best 135×8", selected: true) }
                }
                .padding(14)
            }
            Divider().background(RSTheme.hairline)

            Button {
                applyCoachingTarget(to: exercise)
            } label: {
                HStack(alignment: .top) {
                    Image(systemName: "arrow.up.circle.fill")
                    VStack(alignment: .leading) {
                        Text("Same as last session.").font(RSTheme.mono(12))
                        Text("Target: >= 135 x 8 @ 8 RPE").font(RSTheme.mono(12, weight: .bold)).foregroundStyle(RSTheme.signal)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RSTheme.signal.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(RSTheme.signal))
            }
            .buttonStyle(.plain)
            .padding(14)

            Eyebrow(text: "Sets").padding(.horizontal, 14)
            ForEach(sortedSets) { set in
                SetRowView(
                    set: set,
                    inheritedWeight: store.inheritedWeight(for: set, in: exercise),
                    inheritedReps: store.inheritedReps(for: set, in: exercise),
                    settings: settings,
                    stacked: dynamicType.isAccessibilitySize,
                    complete: { store.complete(set: set, in: exercise, context: context, bodyweightKg: bodyMetrics.first?.bodyweightKg) },
                    delete: { exercise.sets?.removeAll { $0.id == set.id }; try? context.save() },
                    plateCalc: { showingPlateCalcFor = set }
                )
            }
            Button("Add set") {
                exercise.sets?.append(SetEntry(index: sortedSets.count + 1, weightKg: sortedSets.last?.weightKg, reps: sortedSets.last?.reps, restSeconds: settings.defaultRestSeconds))
                try? context.save()
            }
            .buttonStyle(RSButtonStyle(kind: .quiet))
            .padding(14)
        }
    }

    private func groupPosition(for exercise: SessionExercise) -> Int {
        (workoutPage.exercises.firstIndex { $0.id == exercise.id } ?? 0) + 1
    }

    private func canMove(_ exercise: SessionExercise, by offset: Int) -> Bool {
        guard let current = exercises.firstIndex(where: { $0.id == exercise.id }) else { return false }
        return exercises.indices.contains(current + offset)
    }

    private func canGroup(_ exercise: SessionExercise, by offset: Int) -> Bool {
        guard let current = exercises.firstIndex(where: { $0.id == exercise.id }) else { return false }
        let target = current + offset
        guard exercises.indices.contains(target) else { return false }
        return exercises[target].groupID == nil || exercises[target].groupID != exercise.groupID
    }

    private func icon(for exercise: SessionExercise) -> String {
        switch exercise.primaryMuscle {
        case .chest: "▰"
        case .back: "▤"
        case .legs: "▲"
        case .shoulders: "△"
        case .arms: "◆"
        case .core: "◈"
        case .cardio: "◌"
        }
    }

    private func applyCoachingTarget(to exercise: SessionExercise) {
        let sortedSets = (exercise.sets ?? []).sorted { $0.index < $1.index }
        let baseWeight = sortedSets.compactMap(\.weightKg).last ?? sortedSets.compactMap { store.inheritedWeight(for: $0, in: exercise) }.last ?? 60
        sortedSets.filter { !$0.isCompleted && $0.type == .working }.forEach {
            $0.weightKg = baseWeight
            $0.reps = 8
            $0.rpe = 8
        }
        try? context.save()
    }
}

struct SetRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var set: SetEntry
    let inheritedWeight: Double?
    let inheritedReps: Int?
    let settings: AppSettings
    let stacked: Bool
    let complete: () -> Void
    let delete: () -> Void
    let plateCalc: () -> Void
    @State private var showingRPE = false

    var body: some View {
        VStack(spacing: 6) {
            if stacked {
                stackedLayout
            } else {
                gridLayout
            }
            if showingRPE && !set.isCompleted {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(stride(from: 6.0, through: 10.0, by: 0.5)), id: \.self) { value in
                            Button { set.rpe = value; showingRPE = false } label: { RSChip(text: String(format: "%.1f", value), selected: set.rpe == value) }
                        }
                    }
                }
            }
            if set.isPR {
                HStack { Text("PR").font(RSTheme.mono(10, weight: .bold)); Text("New personal record").font(RSTheme.mono(11)); Spacer() }
                    .foregroundStyle(RSTheme.pr)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .opacity(set.isCompleted ? 0.55 : 1)
        .background(RSTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(RSTheme.hairline).frame(height: 1) }
        .swipeActions { Button("Delete", role: .destructive, action: delete) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(set.index), \(set.type.title), previous \(previousText), weight \(displayWeightText), reps \(set.reps ?? inheritedReps ?? 0), \(set.isCompleted ? "completed" : "not completed")")
        .accessibilityAction(named: "Complete set", complete)
    }

    private var gridLayout: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SetKind.allCases) { kind in Button(kind.title) { set.type = kind } }
            } label: { Text("\(set.type.shortTitle)\(set.index)").font(RSTheme.mono(11, weight: .bold)).frame(width: 34, height: 44) }
            Text(previousText).font(RSTheme.mono(10)).foregroundStyle(RSTheme.textTertiary).frame(width: 52)
            weightField.frame(width: 76)
            repsField.frame(width: 54)
            if settings.showRPE { Button(set.rpe.map { String(format: "%.1f", $0) } ?? "--") { showingRPE.toggle() }.font(RSTheme.mono(12)).frame(width: 44, height: 44) }
            Text(restText).font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary).frame(width: 44)
            Button(action: complete) {
                Image(systemName: set.isCompleted ? "checkmark" : "circle")
                    .frame(width: 52, height: 44)
                    .background(set.isCompleted ? RSTheme.signal : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(set.isCompleted)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.25), value: set.isCompleted)
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("SET \(set.index) · \(set.type.title.uppercased())").font(RSTheme.mono(12, weight: .bold)); Spacer(); Text("PREV \(previousText)").font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary) }
            HStack { weightField; repsField }
            Button("RPE \(set.rpe.map { String(format: "%.1f", $0) } ?? "--") · REST \(restText)") { showingRPE.toggle() }.font(RSTheme.mono(12))
            Button(set.isCompleted ? "Completed" : "Complete", action: complete).buttonStyle(RSButtonStyle(kind: .primary)).disabled(set.isCompleted)
        }
        .hairlineCard()
    }

    private var weightField: some View {
        TextField("KG", value: Binding(get: { set.weightKg ?? inheritedWeight ?? 0 }, set: { set.weightKg = $0; set.touchedWeight = true }), format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .font(RSTheme.mono(13))
            .onLongPressGesture(perform: plateCalc)
    }

    private var repsField: some View {
        TextField("Reps", value: Binding(get: { set.reps ?? inheritedReps ?? 0 }, set: { set.reps = $0; set.touchedReps = true }), format: .number)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .font(RSTheme.mono(13))
    }

    private var previousText: String {
        guard let w = inheritedWeight, let r = inheritedReps else { return "--" }
        return "\(Int(w))×\(r)"
    }
    private var displayWeightText: String { "\(set.weightKg ?? inheritedWeight ?? 0)" }
    private var restText: String { String(format: "%d:%02d", set.restSeconds / 60, set.restSeconds % 60) }
}

struct BottomWorkoutPill: View {
    let pageText: String
    let minimize: () -> Void
    let progression: () -> Void
    let index: () -> Void
    let share: () -> Void
    let finish: () -> Void
    var body: some View {
        HStack {
            Button(action: minimize) { Image(systemName: "xmark") }
            Button("PROG", action: progression).font(RSTheme.mono(12, weight: .bold))
            Button("‹ \(pageText) ›", action: index).font(RSTheme.mono(12, weight: .bold))
            Button(action: share) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Share workout summary")
            Spacer()
            Button("Finish", action: finish).font(RSTheme.mono(12, weight: .bold))
        }
        .padding(10)
        .background(RSTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(RSTheme.hairline))
    }
}

struct RestTimerPill: View {
    let rest: RestTimerState
    let extend: () -> Void
    let skip: () -> Void
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack {
            Text(label).font(RSTheme.mono(18, weight: .bold)).foregroundStyle(rest.overtime(at: now) > 0 ? RSTheme.warn : RSTheme.signal)
            ProgressView(value: rest.progress(at: now)).tint(rest.overtime(at: now) > 0 ? RSTheme.warn : RSTheme.signal)
            Button("+30", action: extend)
            Button("Skip", action: skip)
        }
        .font(RSTheme.mono(12, weight: .semibold))
        .padding(10)
        .background(RSTheme.surfaceRaised)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(RSTheme.hairline))
        .onReceive(timer) { now = $0 }
    }
    private var label: String {
        let overtime = rest.overtime(at: now)
        if overtime > 0 { return "+\(Int(overtime / 60)):\(String(format: "%02d", Int(overtime) % 60))" }
        let remaining = Int(rest.remaining(at: now))
        return "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
    }
}

struct ExerciseIndexSheet: View {
    let pages: [WorkoutExercisePage]
    @Binding var selectedPage: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    Button {
                        selectedPage = index
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(page.title)
                                Text("\(page.completedSets)/\(page.totalSets) sets · \(Int(volume(page))) kg\(page.isGroup ? " · superset" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if page.exercises.flatMap({ $0.sets ?? [] }).contains(where: \.isPR) { RSChip(text: "PR", selected: true) }
                        }
                    }
                }
            }
            .navigationTitle("Exercise Index")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
    private func volume(_ page: WorkoutExercisePage) -> Double {
        page.exercises.flatMap { $0.sets ?? [] }.reduce(0) { $0 + TrainingMath.volumeKg(weightKg: $1.weightKg ?? 0, reps: $1.reps ?? 0, kind: $1.type, latestBodyweightKg: nil) }
    }
}

struct ProgressionPanelView: View {
    @Bindable var exercise: SessionExercise
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab = "PROG"
    var rule: ProgressionRule { exercise.progressionRule ?? ProgressionRule() }
    var baseWeightKg: Double { (exercise.sets ?? []).compactMap(\.weightKg).last ?? 60 }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("Tab", selection: $tab) {
                        ForEach(["PROG","CHART","LOG","NOTES"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if tab == "PROG" {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Progression rule")
                            Picker("Method", selection: ruleTypeBinding) {
                                ForEach(ProgressionRuleType.allCases) { type in
                                    Text(type.title).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            ruleEditorRows
                        }
                        .hairlineCard()
                        prescriptionList
                        if rule.type == .ladder {
                            ladderList
                        }
                    } else if tab == "CHART" {
                        ChartCard(title: "Exercise Chart", values: [0.2,0.4,0.35,0.7], insight: "Chart data loads lazily and never blocks set entry.")
                    } else if tab == "LOG" {
                        Text("Full set history appears here after completed sessions.").hairlineCard()
                    } else {
                        TextEditor(text: $exercise.note).frame(minHeight: 160).hairlineCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Progression")
            .toolbar { Button("Done") { dismiss() } }
            .appBackground()
        }
    }

    @ViewBuilder private var ruleEditorRows: some View {
        switch rule.type {
        case .ladder:
            Stepper("Rep range low \(rule.repRangeLow)", value: intBinding(\.repRangeLow), in: 1...30)
            Stepper("Rep range high \(rule.repRangeHigh)", value: intBinding(\.repRangeHigh), in: max(rule.repRangeLow, 1)...30)
            Stepper("RPE <= \(rule.maxQualifyingRPE, specifier: "%.1f")", value: doubleBinding(\.maxQualifyingRPE), in: 6...10, step: 0.5)
            Stepper("Sets/session >= \(rule.qualifyingSetsRequired)", value: intBinding(\.qualifyingSetsRequired), in: 1...6)
            Stepper("Increment +\(rule.incrementKg, specifier: "%.1f") kg", value: doubleBinding(\.incrementKg), in: 0.5...10, step: 0.5)
        case .fiveThreeOne:
            Stepper("Training max \(rule.trainingMaxKg, specifier: "%.1f") kg", value: doubleBinding(\.trainingMaxKg), in: 20...400, step: 2.5)
            Stepper("Plate increment \(rule.incrementKg, specifier: "%.1f") kg", value: doubleBinding(\.incrementKg), in: 0.5...10, step: 0.5)
            Text("Three-week 5/5/5+, 3/3/3+, 5/3/1+ prescriptions are generated from training max.")
                .font(RSTheme.mono(12))
                .foregroundStyle(RSTheme.textSecondary)
        case .percentageWave:
            Stepper("Training max \(rule.trainingMaxKg, specifier: "%.1f") kg", value: doubleBinding(\.trainingMaxKg), in: 20...400, step: 2.5)
            Stepper("Target reps \(rule.repRangeLow)", value: intBinding(\.repRangeLow), in: 1...20)
            Stepper("RPE <= \(rule.maxQualifyingRPE, specifier: "%.1f")", value: doubleBinding(\.maxQualifyingRPE), in: 6...10, step: 0.5)
            Text("Default waves: \(rule.wavePercentages.map { "\(($0 * 100).formatted(.number.precision(.fractionLength(0))))%" }.joined(separator: " · "))")
                .font(RSTheme.mono(12))
                .foregroundStyle(RSTheme.textSecondary)
        case .rirAutoregulation:
            Stepper("Target RIR \(rule.targetRIR, specifier: "%.1f")", value: doubleBinding(\.targetRIR), in: 0...5, step: 0.5)
            Stepper("Load adjustment \(rule.rirLoadAdjustmentKg, specifier: "%.1f") kg", value: doubleBinding(\.rirLoadAdjustmentKg), in: 0.5...10, step: 0.5)
            Stepper("Default reps \(rule.repRangeLow)", value: intBinding(\.repRangeLow), in: 1...20)
        }
    }

    private var prescriptionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Prescription")
            ForEach(store.progressionService.prescriptions(rule: rule, baseWeightKg: baseWeightKg, recentSets: exercise.sets ?? [])) { item in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(RSTheme.mono(13, weight: .bold))
                        Text(item.detail).font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary)
                    }
                    Spacer()
                    Text("\(item.targetWeightKg, specifier: "%.1f") x \(item.targetReps)")
                        .font(RSTheme.mono(13, weight: .bold))
                        .foregroundStyle(RSTheme.signal)
                }
                .padding(.vertical, 4)
            }
        }
        .hairlineCard()
    }

    private var ladderList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Ladder")
            ForEach(store.progressionService.ladder(rule: rule, baseWeightKg: baseWeightKg, qualifyingSets: exercise.sets ?? [])) { level in
                HStack {
                    Text("\(level.weightKg, specifier: "%.1f") × \(level.reps)").font(RSTheme.mono(14, weight: level.current ? .bold : .regular))
                    Spacer()
                    if level.completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(RSTheme.signal) }
                    if level.current { RSChip(text: "Current", selected: true) }
                }
                .padding(8)
                .background(level.current ? RSTheme.signal.opacity(0.12) : .clear)
            }
        }
        .hairlineCard()
    }

    private var ruleTypeBinding: Binding<ProgressionRuleType> {
        Binding {
            rule.type
        } set: { value in
            ensureRule().type = value
        }
    }

    private func intBinding(_ keyPath: ReferenceWritableKeyPath<ProgressionRule, Int>) -> Binding<Int> {
        Binding {
            rule[keyPath: keyPath]
        } set: { value in
            ensureRule()[keyPath: keyPath] = value
            rule.updatedAt = Date()
        }
    }

    private func doubleBinding(_ keyPath: ReferenceWritableKeyPath<ProgressionRule, Double>) -> Binding<Double> {
        Binding {
            rule[keyPath: keyPath]
        } set: { value in
            ensureRule()[keyPath: keyPath] = value
            rule.updatedAt = Date()
        }
    }

    private func ensureRule() -> ProgressionRule {
        if let existing = exercise.progressionRule { return existing }
        let created = ProgressionRule()
        exercise.progressionRule = created
        return created
    }
}

struct PlateCalculatorView: View {
    @Bindable var set: SetEntry
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var target: Double = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Target kg", value: $target, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                Text("Bar \(settings.barWeightKg, specifier: "%.1f") kg · step \(settings.plateStepKg, specifier: "%.1f") kg").font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                Text("Load per side: \(max(0, (target - settings.barWeightKg) / 2), specifier: "%.1f") kg").font(RSTheme.mono(22, weight: .bold))
                Button("Apply") { set.weightKg = target; dismiss() }.buttonStyle(RSButtonStyle(kind: .primary))
            }
            .padding()
            .navigationTitle("Plate Calculator")
            .toolbar { Button("Close") { dismiss() } }
            .onAppear { target = set.weightKg ?? 0 }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
