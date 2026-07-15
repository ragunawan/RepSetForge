import SwiftUI
import SwiftData

/// Full-screen active-workout container (dev spec §1 `ActiveWorkoutSheet`).
/// Hosts one `ExerciseFocusView` per `SessionExercise` in a paged TabView.
/// Minimize dismisses back to the tab shell without ending the session —
/// swipe-to-dismiss is blocked so it can't happen by accident (dev spec §1).
/// Restore-UX staleness handling (silent resume under 4h, resume/finish/
/// discard sheet beyond that) lives one level up in `ContentView`, since it
/// has to gate presentation of this view rather than run inside it.
struct ActiveWorkoutView: View {
    let session: WorkoutSession
    let onMinimize: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var restTimer = RestTimerManager()
    @State private var selectedExerciseID: UUID?
    @State private var isPresentingAddExercise = false
    @State private var isPresentingIndex = false
    @State private var isPresentingFinishConfirmation = false

    private var sessionExercises: [SessionExercise] {
        session.sessionExercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        Group {
            if sessionExercises.isEmpty {
                emptyState
            } else {
                TabView(selection: currentSelection) {
                    ForEach(Array(sessionExercises.enumerated()), id: \.element.id) { offset, sessionExercise in
                        ExerciseFocusView(
                            session: session,
                            sessionExercise: sessionExercise,
                            restTimer: restTimer,
                            onOpenIndex: { isPresentingIndex = true },
                            onMinimize: onMinimize,
                            pageNumber: offset + 1,
                            pageCount: sessionExercises.count
                        )
                        .tag(sessionExercise.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(RepSetForgeTheme.Colors.surface)
        .interactiveDismissDisabled(true)
        .onAppear {
            RestTimerNotificationScheduler.requestAuthorizationIfNeeded()
        }
        // `restTimer` is one shared instance across every page in this
        // session, so the notification hook lives here rather than in
        // ExerciseFocusView — Start/Extend/Skip on the pill all funnel
        // through this single `restEndDate` regardless of which page is
        // currently visible.
        .onChange(of: restTimer.restEndDate) { _, newEndDate in
            RestTimerNotificationScheduler.reschedule(endDate: newEndDate)
        }
        .sheet(isPresented: $isPresentingAddExercise) {
            ExerciseSelectionSheet { exercise in addExercise(exercise) }
        }
        .sheet(isPresented: $isPresentingIndex) {
            ExerciseIndexSheet(
                session: session,
                onJump: { sessionExercise in selectedExerciseID = sessionExercise.id },
                onAddExercise: {
                    isPresentingIndex = false
                    isPresentingAddExercise = true
                },
                onFinish: {
                    isPresentingIndex = false
                    isPresentingFinishConfirmation = true
                },
                onCancelWorkout: {
                    isPresentingIndex = false
                    cancelWorkout()
                }
            )
        }
        .sheet(isPresented: $isPresentingFinishConfirmation) {
            FinishWorkoutConfirmationSheet(session: session) {
                finishWorkout()
            }
        }
    }

    /// TabView selection kept non-Optional to avoid tag/selection type
    /// mismatches; falls back to the first exercise when nothing (or a
    /// deleted exercise) is selected.
    private var currentSelection: Binding<UUID> {
        Binding(
            get: {
                if let selectedExerciseID, sessionExercises.contains(where: { $0.id == selectedExerciseID }) {
                    return selectedExerciseID
                }
                return sessionExercises.first?.id ?? UUID()
            },
            set: { selectedExerciseID = $0 }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(session.name)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Text("Add your first exercise to start logging.")
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            Button {
                isPresentingAddExercise = true
            } label: {
                Text("+ Add Exercise")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(RepSetForgeTheme.Colors.signal, in: Capsule())
                    .foregroundStyle(.black)
            }
            Button("Minimize", action: onMinimize)
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addExercise(_ exercise: Exercise) {
        let nextOrder = (sessionExercises.map(\.order).max() ?? -1) + 1
        let sessionExercise = SessionExercise(exercise: exercise, order: nextOrder)
        sessionExercise.session = session
        modelContext.insert(sessionExercise)
        selectedExerciseID = sessionExercise.id
    }

    /// Flips the session to `.completed`; the caller's `fullScreenCover`
    /// re-renders in place from `ActiveWorkoutView` to `WorkoutSummaryView`
    /// once it observes `session.status` change (see `ContentView`).
    private func finishWorkout() {
        session.endedAt = .now
        session.status = .completed
        session.routine?.lastPerformedAt = .now
        isPresentingFinishConfirmation = false
    }

    /// "Cancel workout lives behind the ⋯ overflow with a destructive
    /// confirmation" (dev spec §1) — deletes the session entirely, cascading
    /// to its SessionExercises/SetEntries, and returns to the tab shell.
    private func cancelWorkout() {
        modelContext.delete(session)
        onMinimize()
    }
}
