import SwiftUI

/// Read-only overview of every exercise in the session — navigation and
/// orientation only, no set entry (dev spec §3, mockup frame 2). Reorder and
/// superset grouping are still TODO.md work.
struct ExerciseIndexSheet: View {
    let session: WorkoutSession
    let onJump: (SessionExercise) -> Void
    let onAddExercise: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var sessionExercises: [SessionExercise] {
        session.sessionExercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            List(sessionExercises) { sessionExercise in
                Button {
                    onJump(sessionExercise)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sessionExercise.exercise?.name ?? "Exercise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                            Text(completionSummary(for: sessionExercise))
                                .font(RepSetForgeTheme.Typography.mono(12))
                                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    }
                }
                .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle(session.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // The caller owns the actual dismiss/present sequencing
                    // (both sheets are siblings on the same parent) rather
                    // than this view calling `dismiss()` itself.
                    Button(action: onAddExercise) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func completionSummary(for sessionExercise: SessionExercise) -> String {
        let sets = sessionExercise.setEntries
        let completed = sets.filter { $0.completedAt != nil }.count
        let volume = sets.compactMap(\.volumeKg).reduce(Decimal(0), +)
        return "\(completed)/\(sets.count) sets · \(NSDecimalNumber(decimal: volume).stringValue) kg"
    }
}
