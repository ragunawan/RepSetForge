import SwiftUI
import SwiftData

/// Exercise Selection screen (dev spec §2/§6, mockup frame 3) — replaces the
/// old `AddExerciseSheet` stand-in. `.searchable` with a 150ms debounce;
/// Recents (last 10 used)/Favorites/All sections when no filter is active,
/// a flat "Results" section once search text or a chip filter is active.
/// Muscle + equipment chips are AND-combined across the two categories (OR
/// within a category). Row tap expands an inline history preview — it does
/// not select; only "Add to workout" does. The dedup-aware create flow
/// (`CreateExerciseForm`) is reachable both from the "Create '<query>'" row
/// and the first-run empty state.
struct ExerciseSelectionSheet: View {
    let onAdd: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    // Unfiltered + in-memory matched, consistent with this codebase's other
    // relationship-heavy queries (see ExerciseFocusView's note on
    // #Predicate risk in this environment).
    @Query private var allSessions: [WorkoutSession]
    @Query private var allSetEntries: [SetEntry]

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var expandedExerciseID: UUID?
    @State private var isPresentingCreateForm = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFiltering: Bool {
        !debouncedSearchText.trimmingCharacters(in: .whitespaces).isEmpty
            || !selectedMuscles.isEmpty || !selectedEquipment.isEmpty
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter(matches)
    }

    private var recents: [Exercise] {
        let dated = allExercises.compactMap { exercise -> (Exercise, Date)? in
            guard let date = lastUsed(exercise) else { return nil }
            return (exercise, date)
        }
        return dated.sorted { $0.1 > $1.1 }.prefix(10).map(\.0)
    }

    private var favorites: [Exercise] {
        allExercises.filter(\.isFavorite)
    }

    var body: some View {
        NavigationStack {
            List {
                if !allExercises.isEmpty {
                    chipFilterRow
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 8, trailing: 14))
                        .listRowBackground(Color.clear)
                }

                if allExercises.isEmpty {
                    firstRunEmptyState
                } else if isFiltering {
                    resultsSection
                } else {
                    if !recents.isEmpty {
                        Section("Recents") {
                            ForEach(recents) { row($0) }
                        }
                    }
                    if !favorites.isEmpty {
                        Section("Favorites") {
                            ForEach(favorites) { row($0) }
                        }
                    }
                    Section("All") {
                        ForEach(allExercises) { row($0) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RepSetForgeTheme.Colors.surface)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if !Task.isCancelled { debouncedSearchText = searchText }
        }
        .sheet(isPresented: $isPresentingCreateForm) {
            CreateExerciseForm(
                initialName: debouncedSearchText,
                initialMuscles: selectedMuscles,
                initialEquipment: selectedEquipment.count == 1 ? selectedEquipment.first : nil,
                existingExercises: allExercises,
                onCreate: { exercise in
                    modelContext.insert(exercise)
                    onAdd(exercise)
                    dismiss()
                },
                onSelectExisting: { exercise in
                    onAdd(exercise)
                    dismiss()
                }
            )
        }
    }

    // MARK: - Chip filters

    private var chipFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(MuscleGroup.allCases) { group in
                    let isSelected = selectedMuscles.contains(group)
                    chip(group.displayName, isSelected: isSelected) {
                        if isSelected { selectedMuscles.remove(group) } else { selectedMuscles.insert(group) }
                    }
                }
                ForEach(Equipment.allCases) { equipment in
                    let isSelected = selectedEquipment.contains(equipment)
                    chip(equipment.displayName, isSelected: isSelected) {
                        if isSelected { selectedEquipment.remove(equipment) } else { selectedEquipment.insert(equipment) }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? RepSetForgeTheme.Colors.signalDim : RepSetForgeTheme.Colors.surfaceInput, in: Capsule())
                .foregroundStyle(isSelected ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func matches(_ exercise: Exercise) -> Bool {
        let query = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty && !exercise.name.localizedCaseInsensitiveContains(query) { return false }
        if !selectedMuscles.isEmpty && Set(exercise.muscleGroups).isDisjoint(with: selectedMuscles) { return false }
        if !selectedEquipment.isEmpty && !selectedEquipment.contains(exercise.equipment) { return false }
        return true
    }

    // MARK: - Results / rows

    @ViewBuilder
    private var resultsSection: some View {
        Section("Results") {
            if filteredExercises.isEmpty {
                Text("No matches")
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            } else {
                ForEach(filteredExercises) { row($0) }
            }
            createRow
        }
    }

    @ViewBuilder
    private var createRow: some View {
        let trimmed = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            Button {
                isPresentingCreateForm = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create \"\(trimmed)\"")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                        if let hint = similarExistsHint {
                            Text(hint)
                                .font(.system(size: 12))
                                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    Text("+")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.signal)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
        }
    }

    private var similarExistsHint: String? {
        let matches = ExerciseDedupService.similarExercises(to: debouncedSearchText, in: allExercises)
        guard let first = matches.first else { return nil }
        return "Similar exists: \(first.exercise.name)"
    }

    @ViewBuilder
    private func row(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    expandedExerciseID = expandedExerciseID == exercise.id ? nil : exercise.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                            // Not gold — gold is reserved for PRs (RepSetForgeTheme note).
                            if exercise.isFavorite {
                                Text("★")
                                    .font(.system(size: 11))
                                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                            }
                        }
                        Text(rowSubtitle(exercise))
                            .font(.system(size: 12))
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expandedExerciseID == exercise.id ? 90 : 0))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if expandedExerciseID == exercise.id {
                historyPreview(exercise)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
    }

    private func rowSubtitle(_ exercise: Exercise) -> String {
        var parts: [String] = []
        if let primary = exercise.muscleGroups.first { parts.append(primary.displayName) }
        parts.append(exercise.equipment.displayName)
        if let date = lastUsed(exercise) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            parts.append(formatter.localizedString(for: date, relativeTo: .now))
        }
        return parts.joined(separator: " · ")
    }

    private func lastUsed(_ exercise: Exercise) -> Date? {
        allSessions
            .filter { $0.status == .completed }
            .compactMap { session -> Date? in
                session.sessionExercises.contains { $0.exercise?.id == exercise.id } ? session.startedAt : nil
            }
            .max()
    }

    // MARK: - Inline history preview

    private func historyPreview(_ exercise: Exercise) -> some View {
        let qualifying = ExerciseHistoryService.qualifyingSets(exerciseID: exercise.id, in: allSetEntries)
        let stats = ExerciseHistoryService.bestStats(from: qualifying)
        let points = Array(ExerciseHistoryService.trendPoints(from: qualifying).suffix(6))

        return VStack(alignment: .leading, spacing: 8) {
            if stats.bestWeight == nil {
                Text("No history yet")
                    .font(.system(size: 12))
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            } else {
                HStack {
                    statPair("Best", stats.bestWeight.map { "\(Self.formatDecimal($0)) kg × \(stats.repsAtBestWeight.map(String.init) ?? "—")" } ?? "—")
                    Spacer()
                    statPair("e1RM", stats.bestE1RM.map { "\(Self.formatDecimal($0)) kg" } ?? "—")
                }
                if points.count > 1 {
                    miniSparkline(points.map(\.e1RM))
                }
            }

            Button {
                onAdd(exercise)
                dismiss()
            } label: {
                Text("Add to workout")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RepSetForgeTheme.Colors.signal, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: 10))
    }

    private func statPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
        }
    }

    private func miniSparkline(_ values: [Decimal]) -> some View {
        let maxValue = values.max() ?? 0
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == values.count - 1 ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.hairline)
                    .frame(height: barHeight(value, maxValue))
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    private func barHeight(_ value: Decimal, _ maxValue: Decimal) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        let fraction = NSDecimalNumber(decimal: value / maxValue).doubleValue
        return max(4, CGFloat(fraction) * 24)
    }

    // MARK: - First-run empty state

    private var firstRunEmptyState: some View {
        VStack(spacing: 10) {
            Text("Create your first exercise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Text("RepSetForge ships with an empty exercise list — add the ones you actually train.")
                .font(.system(size: 13))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button("+ Create exercise") { isPresentingCreateForm = true }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(RepSetForgeTheme.Colors.signal, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

/// One-screen create-exercise form (dev spec intro: "name + muscle groups +
/// equipment"), dedup-aware via `ExerciseDedupService`. Pre-fills from the
/// parent sheet's active search text / chip filters where unambiguous.
private struct CreateExerciseForm: View {
    let initialName: String
    let initialMuscles: Set<MuscleGroup>
    let initialEquipment: Equipment?
    let existingExercises: [Exercise]
    let onCreate: (Exercise) -> Void
    let onSelectExisting: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedMuscles: Set<MuscleGroup>
    @State private var equipment: Equipment

    init(
        initialName: String,
        initialMuscles: Set<MuscleGroup>,
        initialEquipment: Equipment?,
        existingExercises: [Exercise],
        onCreate: @escaping (Exercise) -> Void,
        onSelectExisting: @escaping (Exercise) -> Void
    ) {
        self.initialName = initialName
        self.initialMuscles = initialMuscles
        self.initialEquipment = initialEquipment
        self.existingExercises = existingExercises
        self.onCreate = onCreate
        self.onSelectExisting = onSelectExisting
        _name = State(initialValue: initialName)
        _selectedMuscles = State(initialValue: initialMuscles)
        _equipment = State(initialValue: initialEquipment ?? .other)
    }

    private var similarMatches: [ExerciseDedupService.Match] {
        ExerciseDedupService.similarExercises(to: name, in: existingExercises)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                if !similarMatches.isEmpty {
                    Section("Similar exists") {
                        ForEach(similarMatches, id: \.exercise.id) { match in
                            Button(match.exercise.name) {
                                onSelectExisting(match.exercise)
                            }
                        }
                    }
                }

                Section("Muscle groups") {
                    muscleGroupPicker
                }

                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Create exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onCreate(makeExercise()) }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var muscleGroupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(MuscleGroup.allCases) { group in
                    let isSelected = selectedMuscles.contains(group)
                    Button {
                        if isSelected { selectedMuscles.remove(group) } else { selectedMuscles.insert(group) }
                    } label: {
                        Text(group.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? RepSetForgeTheme.Colors.signalDim : RepSetForgeTheme.Colors.surfaceInput, in: Capsule())
                            .foregroundStyle(isSelected ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func makeExercise() -> Exercise {
        Exercise(name: name, muscleGroups: Array(selectedMuscles), equipment: equipment)
    }
}
