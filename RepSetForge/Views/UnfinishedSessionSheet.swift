import SwiftUI

/// Restore-UX sheet for a stale active session (dev spec §1): shown on
/// launch instead of a silent resume once a session is >= 4h old. A
/// session that's >= 12h old or has crossed midnight since it started
/// visually promotes "Finish as-is" to the primary action — "prevents
/// accidental 9-hour 'workouts' polluting Health and analytics" — but
/// Resume and Discard stay available either way; nothing here silently
/// drops logged sets.
struct UnfinishedSessionSheet: View {
    let session: WorkoutSession
    let stronglySuggestFinish: Bool
    let onResume: () -> Void
    let onFinishAsIs: () -> Void
    let onDiscard: () -> Void

    @State private var isPresentingDiscardConfirmation = false

    private var completedSets: [SetEntry] {
        session.sessionExercises.flatMap(\.setEntries).filter { $0.completedAt != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Unfinished workout")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                    Text(session.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    Text("Started \(Self.formatTime(session.startedAt)) · \(completedSets.count) sets logged")
                        .font(RepSetForgeTheme.Typography.mono(13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    if stronglySuggestFinish {
                        Text("This session has been open a long time — consider finishing it as-is.")
                            .font(.system(size: 12))
                            .foregroundStyle(RepSetForgeTheme.Colors.warn)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 10) {
                    if stronglySuggestFinish {
                        primaryButton("Finish as-is", action: onFinishAsIs)
                        secondaryButton("Resume", action: onResume)
                    } else {
                        primaryButton("Resume", action: onResume)
                        secondaryButton("Finish as-is", action: onFinishAsIs)
                    }
                    Button("Discard workout", role: .destructive) {
                        isPresentingDiscardConfirmation = true
                    }
                    .foregroundStyle(RepSetForgeTheme.Colors.destructive)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
        }
        .alert("Discard this workout?", isPresented: $isPresentingDiscardConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive, action: onDiscard)
        } message: {
            Text("This permanently deletes \(completedSets.count) logged sets. This can't be undone.")
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RepSetForgeTheme.Colors.signal, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.black)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RepSetForgeTheme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
