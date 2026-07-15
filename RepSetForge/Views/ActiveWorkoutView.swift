import SwiftUI
import SwiftData

/// Full-screen active-workout container (dev spec §1 `ActiveWorkoutSheet`).
/// Hosts one `ExerciseFocusView` per `SessionExercise` in a paged TabView.
/// Minimize dismisses back to the tab shell without ending the session —
/// swipe-to-dismiss is blocked so it can't happen by accident (dev spec §1).
/// The full restore-UX rules (silent resume under 4h, resume/finish/discard
/// sheet beyond that) are still TODO.md work.
struct ActiveWorkoutView: View {
    let session: WorkoutSession
    let onMinimize: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var restTimer = RestTimerManager()
    @State private var selectedExerciseID: UUID?
    @State private var isPresentingAddExercise = false
    @State private var isPresentingIndex = false

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
        .sheet(isPresented: $isPresentingAddExercise) {
            AddExerciseSheet { exercise in addExercise(exercise) }
        }
        .sheet(isPresented: $isPresentingIndex) {
            ExerciseIndexSheet(
                session: session,
                onJump: { sessionExercise in selectedExerciseID = sessionExercise.id },
                onAddExercise: {
                    isPresentingIndex = false
                    isPresentingAddExercise = true
                }
            )
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
}
