import SwiftUI
import SwiftData

/// §5 Library: routine list + builder — drag reorder, superset grouping,
/// targets, per-item rest, progression-rule editor.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.name) private var routines: [Routine]
    @State private var editing: Routine?

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    VStack(spacing: DT.Spacing.s12) {
                        Text("NO ROUTINES YET")
                            .font(DT.Type.eyebrow)
                            .foregroundStyle(DT.Colors.textTertiary)
                        Button("+ New routine") { createRoutine() }
                            .font(DT.Type.body.weight(.bold))
                            .foregroundStyle(DT.Colors.onSignal)
                            .padding(.horizontal, DT.Spacing.s24)
                            .frame(minHeight: DT.Touch.minimum)
                            .background(DT.Colors.signal)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(routines.filter { $0.archivedAt == nil }) { routine in
                            Button { editing = routine } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name).font(DT.Type.body.weight(.bold))
                                    Text("\(routine.orderedItems?.count ?? 0) exercises\(routine.lastPerformedAt.map { " · last \($0.formatted(.relative(presentation: .named)))" } ?? "")")
                                        .font(DT.Type.secondary)
                                        .foregroundStyle(DT.Colors.textSecondary)
                                }
                            }
                            .listRowBackground(DT.Colors.surface)
                            .swipeActions {
                                Button("Archive") { routine.archivedAt = .now }
                                    .tint(DT.Colors.warning)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DT.Colors.surface)
            .navigationTitle("Library")
            .toolbar {
                Button { createRoutine() } label: { Image(systemName: "plus") }
            }
            .sheet(item: $editing) { RoutineBuilderView(routine: $0) }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    private func createRoutine() {
        let r = Routine(name: "New Routine")
        context.insert(r)
        editing = r
    }
}

struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine
    @State private var showPicker = false
    @State private var editingRule: RoutineItem?

    private var items: [RoutineItem] {
        (routine.orderedItems ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name", text: $routine.name)
                        .font(DT.Type.body.weight(.bold))
                }
                Section("EXERCISES") {
                    ForEach(items, id: \.persistentModelID) { item in
                        itemRow(item)
                    }
                    .onMove { from, to in
                        var list = items
                        list.move(fromOffsets: from, toOffset: to)
                        for (i, it) in list.enumerated() { it.order = i }
                    }
                    .onDelete { idx in
                        let list = items
                        for i in idx { context.delete(list[i]) }
                        dissolveSingletonGroups()
                    }
                    Button("+ Add exercise") { showPicker = true }
                        .foregroundStyle(DT.Colors.signal)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercise in
                    let item = RoutineItem(exercise: exercise, order: items.count)
                    item.routine = routine
                    routine.orderedItems?.append(item)
                }
            }
            .sheet(item: $editingRule) { RuleEditorView(item: $0) }
        }
        .font(DT.Type.body)
    }

    private func itemRow(_ item: RoutineItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.exercise?.name ?? "Exercise")
                    .font(DT.Type.body.weight(.bold))
                Spacer()
                if item.groupID != nil {
                    Text("SUPERSET")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.signal)
                }
            }
            HStack(spacing: DT.Spacing.s8) {
                Stepper("\(item.targetSets) sets", value: Bindable(item).targetSets, in: 1...10)
                    .font(DT.Type.secondary)
            }
            HStack {
                Text("\(item.targetRepsLow)–\(item.targetRepsHigh) reps · rest \(item.restSeconds)s")
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
                    .monospacedDigit()
                Spacer()
                Button(item.progressionRule == nil ? "+ Rule" : "Rule ▸") { editingRule = item }
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(DT.Colors.signal)
            }
        }
        .listRowBackground(DT.Colors.surface)
        .contextMenu {
            Button("Superset with next") { supersetWithNext(item) }
            if item.groupID != nil {
                Button("Remove from superset") {
                    item.groupID = nil
                    dissolveSingletonGroups()
                }
            }
        }
    }

    /// Adjacent items with a shared groupID form a superset (one Focus page).
    private func supersetWithNext(_ item: RoutineItem) {
        let list = items
        guard let idx = list.firstIndex(where: { $0.persistentModelID == item.persistentModelID }),
              idx + 1 < list.count else { return }
        let gid = item.groupID ?? UUID()
        item.groupID = gid
        list[idx + 1].groupID = gid
    }

    /// §3 edge case: a group with one remaining member dissolves.
    private func dissolveSingletonGroups() {
        let byGroup = Dictionary(grouping: items.filter { $0.groupID != nil }, by: { $0.groupID! })
        for (_, members) in byGroup where members.count == 1 {
            members[0].groupID = nil
        }
    }
}

/// §3 progression-rule editor rows (double progression, v1.0's only type).
struct RuleEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: RoutineItem

    var body: some View {
        NavigationStack {
            Form {
                if let rule = item.progressionRule {
                    Stepper("Rep range low: \(rule.repRangeLow)",
                            value: Bindable(rule).repRangeLow, in: 1...30)
                    Stepper("Rep range high: \(rule.repRangeHigh)",
                            value: Bindable(rule).repRangeHigh, in: rule.repRangeLow...30)
                    Stepper("Max RPE: \(rule.maxQualifyingRPE.formatted(.number.precision(.fractionLength(0...1))))",
                            value: Bindable(rule).maxQualifyingRPE, in: 5...10, step: 0.5)
                    Stepper("Qualifying sets: \(rule.qualifyingSetsRequired)",
                            value: Bindable(rule).qualifyingSetsRequired, in: 1...5)
                    HStack {
                        Text("Increment")
                        Spacer()
                        Text("+\(NSDecimalNumber(decimal: rule.incrementKg).doubleValue.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            .monospacedDigit()
                    }
                    Button("Remove rule", role: .destructive) {
                        context.delete(rule)
                        item.progressionRule = nil
                        dismiss()
                    }
                } else {
                    Button("Add double-progression rule") {
                        let rule = ProgressionRule()
                        rule.routineItem = item
                        item.progressionRule = rule
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle("Progression rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .font(DT.Type.body)
        .presentationDetents([.medium])
    }
}
