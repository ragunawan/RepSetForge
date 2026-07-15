import SwiftUI
import SwiftData

/// dev spec §5, mockup frame 9 — create or edit a routine. Superset grouping
/// (shared `groupID`) isn't built yet; items are a flat, reorderable,
/// deletable list. The progression-rule editor is wired via
/// `ProgressionRuleEditorSheet` (tap the row's "Progression" line).
///
/// Note on Cancel: for a brand-new routine (`routine == nil`), nothing is
/// inserted into the model context until Save, so Cancel discards cleanly.
/// For an *existing* routine, reordering/target-stepper edits and deletes
/// apply live to the already-persisted `RoutineItem`s as they happen (the
/// row Stepper is bound directly to the model) — Cancel does not currently
/// roll those back. A true edit-then-commit draft would need a separate
/// in-memory copy; not worth the complexity for this pass.
struct RoutineBuilderView: View {
    let routine: Routine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var items: [RoutineItem]
    @State private var isPresentingAddExercise = false
    @State private var editingProgressionRuleItem: RoutineItem?

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _items = State(initialValue: (routine?.items ?? []).sorted { $0.order < $1.order })
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name", text: $name)
                }

                Section("Exercises") {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                    .onMove(perform: moveItems)
                    .onDelete(perform: deleteItems)

                    Button("+ Add exercise") { isPresentingAddExercise = true }
                }
            }
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $isPresentingAddExercise) {
            AddExerciseSheet { exercise in addItem(for: exercise) }
        }
        .sheet(item: $editingProgressionRuleItem) { item in
            if let rule = item.progressionRule {
                ProgressionRuleEditorSheet(rule: rule)
            }
        }
    }

    private func itemRow(_ item: RoutineItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.exercise?.name ?? "Exercise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Stepper(
                "\(item.targetSets) × \(item.targetRepsLow)–\(item.targetRepsHigh)",
                value: Binding(get: { item.targetSets }, set: { item.targetSets = $0 }),
                in: 1...10
            )
            .font(RepSetForgeTheme.Typography.mono(13))
            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)

            Button {
                if item.progressionRule == nil {
                    // Explicit insert (matches this codebase's convention of
                    // never relying on implicit relationship insertion) —
                    // needed here specifically because `save()` only inserts
                    // rules for brand-new items, and this lazily creates one
                    // for a pre-existing item that never had one.
                    let rule = ProgressionRule()
                    item.progressionRule = rule
                    modelContext.insert(rule)
                }
                editingProgressionRuleItem = item
            } label: {
                Text("Progression: \(progressionSummary(for: item))")
                    .font(RepSetForgeTheme.Typography.mono(12, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
    }

    private func progressionSummary(for item: RoutineItem) -> String {
        guard let rule = item.progressionRule else { return "off" }
        return "\(rule.repRangeLow)–\(rule.repRangeHigh) reps · +\(Self.formatDecimal(rule.incrementKg)) kg"
    }

    private func addItem(for exercise: Exercise) {
        // Every item gets a default double-progression rule so the Exercise
        // Focus screen's PROG panel has something to show once a workout is
        // started from this routine; tap the row's "Progression" line to
        // customize it via `ProgressionRuleEditorSheet`.
        items.append(RoutineItem(exercise: exercise, order: items.count, progressionRule: ProgressionRule()))
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.order = index }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            // Only already-persisted items (routine != nil) need an explicit
            // delete — a freshly appended item was never inserted.
            if item.routine != nil {
                modelContext.delete(item)
            }
        }
        items.remove(atOffsets: offsets)
        for (index, item) in items.enumerated() { item.order = index }
    }

    private func save() {
        let targetRoutine = routine ?? Routine(name: name)
        if routine == nil {
            modelContext.insert(targetRoutine)
        }
        targetRoutine.name = name
        for item in items where item.routine == nil {
            item.routine = targetRoutine
            modelContext.insert(item)
            if let rule = item.progressionRule {
                modelContext.insert(rule)
            }
        }
        targetRoutine.items = items
        dismiss()
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
