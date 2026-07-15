import SwiftUI
import SwiftData

/// Minimal stand-in for the `RootView` architecture in dev spec §1 — the
/// TabView shell exists, the FAB starts/resumes a workout, and all four
/// tabs (Home/History/Progress/Library) are now real.
struct ContentView: View {
    private enum Tab: Hashable {
        case home, history, progress, library
    }

    @State private var selectedTab: Tab = .home
    @State private var isPresentingStartWorkout = false
    @State private var activeWorkoutSession: WorkoutSession?

    @AppStorage(AppSettingsKeys.theme) private var theme: ThemePreference = .system

    // Fetched unfiltered and matched in-memory rather than via a #Predicate
    // filter — see ExerciseFocusView's note on relationship-predicate risk.
    // This one's a plain attribute compare so it's lower-risk, but kept
    // consistent for now.
    @Query private var allSessions: [WorkoutSession]

    private var activeSession: WorkoutSession? {
        allSessions.first { $0.status == .active }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(activeSession: activeSession) { session in
                    activeWorkoutSession = session
                }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

                HistoryView()
                    .tabItem { Label("History", systemImage: "list.bullet") }
                    .tag(Tab.history)

                ProgressScreenView()
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(Tab.progress)

                RoutineLibraryView()
                    .tabItem { Label("Library", systemImage: "square.stack.3d.up.fill") }
                    .tag(Tab.library)
            }

            StartWorkoutFAB(isActive: activeSession != nil) {
                if let activeSession {
                    activeWorkoutSession = activeSession
                } else {
                    isPresentingStartWorkout = true
                }
            }
            .padding(.bottom, 50)
        }
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $isPresentingStartWorkout) {
            StartWorkoutSheet { session in
                activeWorkoutSession = session
            }
        }
        .fullScreenCover(item: $activeWorkoutSession) { session in
            // Same presentation throughout — re-renders in place from
            // ActiveWorkoutView to WorkoutSummaryView once `finishWorkout()`
            // flips `session.status`, rather than dismissing and re-presenting.
            if session.status == .completed {
                WorkoutSummaryView(session: session) {
                    activeWorkoutSession = nil
                }
            } else {
                ActiveWorkoutView(session: session) {
                    activeWorkoutSession = nil
                }
            }
        }
    }
}

private struct StartWorkoutFAB: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "arrow.up.right" : "play.fill")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(RepSetForgeTheme.Colors.signal, in: Circle())
        }
        .accessibilityLabel(isActive ? "Resume workout" : "Start workout")
    }
}

#Preview {
    ContentView()
}
