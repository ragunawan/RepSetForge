import SwiftUI
import SwiftData

/// Active Workout screen (§3): TabView(.page) carousel of Exercise Focus
/// pages under a shared telemetry header, with the bottom pill overlay.
struct ActiveWorkoutView: View {
    @Bindable var vm: WorkoutViewModel
    @State private var showIndex = false
    @State private var showProg = false
    var onMinimize: () -> Void = {}
    var onFinish: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            DT.Colors.surface.ignoresSafeArea()
            VStack(spacing: 0) {
                TelemetryHeader(vm: vm)
                TabView(selection: $vm.page) {
                    // §3: a superset group occupies one page.
                    ForEach(Array(vm.pages.enumerated()), id: \.element.first?.persistentModelID) { idx, members in
                        ExerciseFocusPage(vm: vm, pageIndex: idx, members: members, onFinish: onFinish)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            BottomPill(vm: vm,
                       onMinimize: onMinimize,
                       onIndex: { showIndex = true },
                       onProg: { showProg = true })
                .padding(.horizontal, DT.Spacing.s12)
                .padding(.bottom, DT.Spacing.s8)
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showIndex) {
            ExerciseIndexSheet(vm: vm)
        }
        .sheet(isPresented: $showProg) {
            ProgressionPanel(vm: vm)
        }
    }
}

/// §3.1 telemetry: SESSION elapsed, one WORK/REST line (both cumulative,
/// derived from the single rest ledger), % · volume | SET n/m, progress bar.
/// All ticking is OS-driven: SESSION and the running side of WORK/REST are
/// Text(timerInterval:) with ledger-derived offsets — no per-second state.
struct TelemetryHeader: View {
    var vm: WorkoutViewModel

    var body: some View {
        let start = vm.session?.startedAt ?? .now
        let now = Date.now
        let rest = vm.restTimer.cumulativeRest(at: now)
        let far = Date.distantFuture

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("SESSION:").foregroundStyle(DT.Colors.textSecondary)
                Spacer()
                Text(timerInterval: start...far, countsDown: false)
                    .monospacedDigit()
            }
            HStack {
                Text("WORK: ").foregroundStyle(DT.Colors.textSecondary)
                if vm.restTimer.isResting {
                    // Frozen while resting.
                    Text(Duration.seconds(vm.restTimer.cumulativeWork(sessionStart: start, at: now)),
                         format: .time(pattern: .hourMinuteSecond))
                        .monospacedDigit()
                } else {
                    // Runs: offset the timer start by banked rest.
                    Text(timerInterval: start.addingTimeInterval(rest)...far, countsDown: false)
                        .monospacedDigit()
                }
                Spacer()
                Text("REST: ").foregroundStyle(DT.Colors.textSecondary)
                if let restStart = vm.restTimer.restStart {
                    // Runs during rest: banked + current interval.
                    Text(timerInterval: restStart.addingTimeInterval(-(rest - now.timeIntervalSince(restStart)))...far,
                         countsDown: false)
                        .monospacedDigit()
                } else {
                    Text(Duration.seconds(rest), format: .time(pattern: .hourMinuteSecond))
                        .monospacedDigit()
                }
            }
            HStack {
                let pct = vm.totalSets > 0 ? Int(Double(vm.doneSets) / Double(vm.totalSets) * 100) : 0
                let volK = NSDecimalNumber(decimal: vm.volumeKg).doubleValue / 1000
                Text("\(pct)% · \(volK, specifier: "%.1f")k KG")
                Spacer()
                Text("SET \(vm.doneSets)/\(vm.totalSets)")
            }
            .font(DT.Type.secondary)
            .foregroundStyle(DT.Colors.textTertiary)
            .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DT.Colors.surfaceInput)
                    Capsule().fill(DT.Colors.signal)
                        .frame(width: vm.totalSets > 0
                               ? geo.size.width * CGFloat(vm.doneSets) / CGFloat(vm.totalSets) : 0)
                        .animation(DT.Motion.stateChange, value: vm.doneSets)
                }
            }
            .frame(height: 4)
            .padding(.top, DT.Spacing.s4)
        }
        .font(DT.Type.secondary.weight(.semibold))
        .padding(.horizontal, DT.Spacing.s16 + 2)
        .padding(.top, DT.Spacing.s8)
        .padding(.bottom, DT.Spacing.s8)
    }
}
