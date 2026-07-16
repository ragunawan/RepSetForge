import SwiftUI
import SwiftData

/// §1 architecture: TabView (Home · History · Progress · Library) with the
/// FAB overlaid, ActiveWorkoutSheet as fullScreenCover that minimizes (never
/// dismisses), restore branching on launch, finish → summary → Health export.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ActiveSessionStore()
    @State private var vm: WorkoutViewModel?
    @State private var showWorkout = false
    @State private var showRestoreSheet = false
    @State private var suggestFinishAsIs = false
    @State private var showSummary = false
    @State private var healthSaved = false
    @State private var tab = 0
    private let health = HealthKitExporter()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                Group {
                    if let vm {
                        HomeView(vm: vm,
                                 onResume: { showWorkout = true },
                                 onStart: startWorkout(routine:))
                    } else {
                        DT.Colors.surface.ignoresSafeArea()
                    }
                }
                .tabItem { Label("HOME", systemImage: "house") }.tag(0)
                Text("History — Phase 7").tabItem { Label("HIST", systemImage: "calendar") }.tag(1)
                Text("Progress — Phase 7").tabItem { Label("PROG", systemImage: "chart.bar") }.tag(2)
                Text("Library — Phase 7").tabItem { Label("LIB", systemImage: "books.vertical") }.tag(3)
            }
            .tint(DT.Colors.signal)

            if !(vm?.store.isActive ?? false) {
                fab
            } else if !showWorkout {
                activePill
            }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
        .onAppear(perform: bootstrap)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm?.reassertLiveActivityOnForeground() }
        }
        .fullScreenCover(isPresented: $showWorkout) {
            if let vm {
                ActiveWorkoutView(vm: vm,
                                  onMinimize: { showWorkout = false },
                                  onFinish: finishWorkout)
            }
        }
        .sheet(isPresented: $showSummary) {
            if let vm {
                SummaryView(vm: vm, healthSaved: healthSaved) {
                    showSummary = false
                }
            }
        }
        .confirmationDialog("Unfinished workout", isPresented: $showRestoreSheet, titleVisibility: .visible) {
            Button(suggestFinishAsIs ? "Finish as-is (suggested)" : "Finish as-is") {
                vm?.store.finishAsIs()
                vm?.endLiveActivity(discarded: false)
            }
            Button("Resume") { showWorkout = true }
            Button("Discard", role: .destructive) {
                vm?.store.discard()
                vm?.endLiveActivity(discarded: true)
            }
        } message: {
            if let s = store.session {
                Text("\(s.name), started \(s.startedAt.formatted(date: .omitted, time: .shortened)), \(vm?.doneSets ?? 0) sets logged")
            }
        }
    }

    private var fab: some View {
        Button {
            startWorkout(routine: nil)
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(DT.Colors.onSignal)
                .frame(width: 52, height: 52)
                .background(DT.Colors.signal)
                .clipShape(Circle())
                .shadow(color: DT.Colors.signal.opacity(DT.Elevation.fabShadowOpacity),
                        radius: DT.Elevation.fabShadowRadius, y: DT.Elevation.fabShadowY)
        }
        .padding(.bottom, 70)
    }

    private var activePill: some View {
        Button { showWorkout = true } label: {
            HStack {
                Text(vm?.session?.name ?? "Workout")
                    .font(DT.Type.secondary.weight(.bold))
                Spacer()
                if let start = vm?.session?.startedAt {
                    Text(start, style: .timer)
                        .font(DT.Type.secondary)
                        .monospacedDigit()
                        .foregroundStyle(DT.Colors.signal)
                }
                Text("›").foregroundStyle(DT.Colors.textTertiary)
            }
            .padding(.horizontal, DT.Spacing.s16)
            .frame(height: 44)
            .background(DT.Colors.surfaceRaised)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(DT.Colors.hairline))
            .shadow(color: DT.Elevation.raisedShadowColor,
                    radius: DT.Elevation.raisedShadowRadius, y: DT.Elevation.raisedShadowY)
            .padding(.horizontal, DT.Spacing.s12)
            .padding(.bottom, 56)
        }
        .buttonStyle(.plain)
    }

    // MARK: lifecycle

    private func bootstrap() {
        guard vm == nil else { return }
        store.configure(context: context)
        let model = WorkoutViewModel(store: store)
        vm = model
        // §1 restore branching.
        switch model.store.restoreAction() {
        case .silentResume, .none:
            break // Home shows the normal resume banner; nothing modal.
        case .promptSheet(let suggest):
            suggestFinishAsIs = suggest
            showRestoreSheet = true
        }
    }

    private func startWorkout(routine: Routine?) {
        guard let vm else { return }
        if !vm.store.isActive {
            vm.store.start(name: routine?.name ?? "Workout", routine: routine)
            seedExercises(from: routine)
            vm.startLiveActivity()
        }
        showWorkout = true
    }

    private func seedExercises(from routine: Routine?) {
        guard let session = store.session, let items = routine?.orderedItems else { return }
        for (i, item) in items.sorted(by: { $0.order < $1.order }).enumerated() {
            let se = SessionExercise(exercise: item.exercise, order: i)
            se.groupID = item.groupID
            se.session = session
            for n in 0..<max(1, item.targetSets) {
                let set = SetEntry(index: n)
                set.sessionExercise = se
                se.sets?.append(set)
            }
            session.exercises?.append(se)
        }
        store.touch()
    }

    private func finishWorkout() {
        guard let vm, let session = vm.session else { return }
        showWorkout = false
        vm.store.finish()
        session.routine?.lastPerformedAt = .now
        vm.endLiveActivity(discarded: false)

        // §4b: permission at first completion; export guarded by healthKitUUID.
        Task {
            let authorized = await health.requestAuthorizationIfNeeded()
            if authorized,
               let ended = session.endedAt {
                let uuid = try? await health.export(
                    name: session.name,
                    startedAt: session.startedAt,
                    endedAt: ended,
                    totalVolumeKg: NSDecimalNumber(decimal: vm.volumeKg).doubleValue,
                    existingUUID: session.healthKitUUID)
                if let uuid {
                    session.healthKitUUID = uuid
                    healthSaved = true
                }
            } else {
                healthSaved = false // fully functional with Health denied
            }
            showSummary = true
        }
    }
}
