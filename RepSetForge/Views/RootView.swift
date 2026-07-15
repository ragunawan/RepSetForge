import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    @State private var showingStart = false
    @State private var showingActive = false
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $store.selectedTab) {
                HomeView(showSettings: { showingSettings = true }, startWorkout: openWorkout)
                    .tabItem { Label("Home", systemImage: RootTab.home.icon) }
                    .tag(RootTab.home)
                HistoryView()
                    .tabItem { Label("History", systemImage: RootTab.history.icon) }
                    .tag(RootTab.history)
                ProgressViewScreen()
                    .tabItem { Label("Progress", systemImage: RootTab.progress.icon) }
                    .tag(RootTab.progress)
                LibraryView()
                    .tabItem { Label("Library", systemImage: RootTab.library.icon) }
                    .tag(RootTab.library)
            }
            .tint(RSTheme.signal)

            VStack(spacing: 8) {
                if store.minimizedSessionVisible, let session = store.activeSession {
                    ActiveWorkoutPill(session: session) {
                        showingActive = true
                        store.minimizedSessionVisible = false
                    }
                    .padding(.horizontal)
                }
                Button {
                    openWorkout()
                } label: {
                    Image(systemName: store.activeSession == nil ? "play.fill" : "arrow.up.forward.app.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 58, height: 58)
                }
                .buttonStyle(RSButtonStyle(kind: .primary))
                .clipShape(Circle())
                .accessibilityIdentifier("startWorkoutFAB")
                .padding(.bottom, 56)
            }
        }
        .appBackground()
        .sheet(isPresented: $showingStart) {
            StartWorkoutSheet { session in
                store.start(session: session, context: context)
                showingStart = false
                showingActive = true
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingActive) {
            if let session = store.activeSession {
                ActiveWorkoutView(session: session) {
                    showingActive = false
                    store.minimizedSessionVisible = true
                }
                .interactiveDismissDisabled(true)
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(item: Binding(get: {
            store.lastSummary.map(SessionSummaryItem.init(session:))
        }, set: { _ in
            store.lastSummary = nil
        })) { item in
            WorkoutSummaryView(session: item.session, healthMessage: store.healthStatusMessage)
        }
        .alert("Unfinished workout", isPresented: Binding(get: { store.restorePrompt != nil }, set: { if !$0 { store.restorePrompt = nil } })) {
            Button("Resume") {
                store.restorePrompt = nil
                showingActive = true
            }
            Button("Finish as-is") {
                store.restorePrompt = nil
                store.finishActiveSession(context: context, bodyweightKg: bodyMetrics.first?.bodyweightKg)
            }
            Button("Discard", role: .destructive) {
                store.activeSession?.status = .discarded
                try? context.save()
                store.activeSession = nil
                store.restorePrompt = nil
            }
        } message: {
            Text(store.restorePrompt ?? "")
        }
    }

    private func openWorkout() {
        if store.activeSession != nil {
            showingActive = true
            store.minimizedSessionVisible = false
        } else {
            showingStart = true
        }
    }
}

struct SessionSummaryItem: Identifiable {
    let session: WorkoutSession
    var id: UUID { session.id }
}

struct ActiveWorkoutPill: View {
    let session: WorkoutSession
    let resume: () -> Void

    var body: some View {
        Button(action: resume) {
            HStack {
                VStack(alignment: .leading) {
                    Eyebrow(text: "Workout in progress")
                    Text(session.name).font(RSTheme.mono(14, weight: .bold))
                    Text("\(session.completedSetCount) sets done").font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary)
                }
                Spacer()
                RSChip(text: "Resume", selected: true)
            }
            .hairlineCard(radius: RSTheme.pillRadius)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activeWorkoutPill")
    }
}

