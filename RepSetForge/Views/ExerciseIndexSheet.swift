import SwiftUI

/// Read-only overview of every exercise in the session — navigation and
/// orientation only, no set entry (dev spec §3, mockup frame 2). Reorder and
/// superset grouping are still TODO.md work.
struct ExerciseIndexSheet: View {
    let session: WorkoutSession
    let onJump: (SessionExercise) -> Void
    let onAddExercise: () -> Void
    let onFinish: () -> Void
    let onCancelWorkout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingCancelConfirmation = false

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
                    // Cancel workout lives behind the ⋯ overflow with a
                    // destructive confirmation (dev spec §1).
                    Menu {
                        Button(role: .destructive) {
                            isPresentingCancelConfirmation = true
                        } label: {
                            Label("Cancel workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // The caller owns the actual dismiss/present sequencing for
                // both actions (they're siblings on the same parent) rather
                // than this view calling `dismiss()` itself.
                HStack(spacing: 8) {
                    Button(action: onAddExercise) {
                        Text("+ Exercise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
                    }
                    Button(action: onFinish) {
                        Text("Finish")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    }
                    .disabled(sessionExercises.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RepSetForgeTheme.Colors.surface)
            }
            .confirmationDialog(
                "Cancel this workout?",
                isPresented: $isPresentingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive, action: onCancelWorkout)
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("This deletes everything logged in this session. This can't be undone.")
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
