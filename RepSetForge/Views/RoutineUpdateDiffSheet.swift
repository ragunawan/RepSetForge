import SwiftUI
import SwiftData

/// Post-workout routine-update sheet (dev spec §5) — per-change toggles,
/// default off (every change this build produces is "structural"; see
/// `RoutineDiffService`'s doc comment on the weight-change gap). "Apply"
/// commits only the toggled-on changes back onto the routine's `RoutineItem`s.
struct RoutineUpdateDiffSheet: View {
    let routine: Routine
    let changes: [RoutineDiffService.Change]
    let onApply: (Set<String>) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(routine.name) ran a little different than planned. Update the routine to match?")
                        .font(.system(size: 13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Changes") {
                    ForEach(changes) { change in
                        Toggle(isOn: binding(for: change)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.exercise.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                                Text(description(for: change))
                                    .font(.system(size: 12))
                                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                            }
                        }
                        .tint(RepSetForgeTheme.Colors.signal)
                    }
                    .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Update routine?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(selectedIDs)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private func binding(for change: RoutineDiffService.Change) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(change.id) },
            set: { isOn in
                if isOn { selectedIDs.insert(change.id) } else { selectedIDs.remove(change.id) }
            }
        )
    }

    private func description(for change: RoutineDiffService.Change) -> String {
        switch change.kind {
        case .exerciseAdded(let setCount):
            return "Add to routine · \(setCount) set\(setCount == 1 ? "" : "s") logged"
        case .exerciseRemoved:
            return "Not performed this session · remove from routine"
        case .setCountChanged(let from, let to):
            return "\(from) → \(to) sets"
        }
    }
}
