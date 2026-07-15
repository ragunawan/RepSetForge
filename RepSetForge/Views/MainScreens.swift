import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Routine.lastPerformedAt, order: .forward) private var routines: [Routine]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    let showSettings: () -> Void
    let startWorkout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ScreenTitle(text: "Home")
                    if let session = store.activeSession {
                        Button(action: startWorkout) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Eyebrow(text: "Workout in progress")
                                    Text(session.name).font(RSTheme.mono(16, weight: .bold))
                                    Text("\(Int(session.duration / 60)) min · \(session.completedSetCount) sets done").font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                                }
                                Spacer()
                                RSChip(text: "Resume", selected: true)
                            }
                        }
                        .buttonStyle(.plain)
                        .hairlineCard()
                    }
                    WeekCard(sessions: sessions)
                    RecommendedCard(routines: routines, action: startWorkout)
                    BodyCard(metrics: bodyMetrics)
                }
                .padding(RSTheme.screenPadding)
            }
            .navigationTitle("")
            .toolbar {
                Button(action: showSettings) {
                    Text("RN").font(RSTheme.mono(12, weight: .bold))
                }
                .accessibilityLabel("Open Settings")
            }
            .appBackground()
        }
    }
}

struct WeekCard: View {
    let sessions: [WorkoutSession]
    var completedThisWeek: [WorkoutSession] {
        sessions.filter { $0.status == .completed && Calendar.current.isDate($0.startedAt, equalTo: Date(), toGranularity: .weekOfYear) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "This week")
                Spacer()
                Text(completedThisWeek.isEmpty ? "Start streak" : "\(streakWeeks) wk streak")
                    .font(RSTheme.mono(11, weight: .semibold))
                    .foregroundStyle(RSTheme.signal)
            }
            HStack {
                MetricTile(value: "\(completedThisWeek.count)/4", label: "Sessions")
                MetricTile(value: "\(Int(volume / 1000))k", label: "Volume")
                MetricTile(value: "\(sets)", label: "Sets")
                MetricTile(value: "\(prs)", label: "PRs", tint: RSTheme.pr)
            }
            MiniBarChart(values: weeklySetBars)
        }
        .hairlineCard()
    }
    private var sets: Int { completedThisWeek.reduce(0) { $0 + $1.completedSetCount } }
    private var prs: Int { completedThisWeek.flatMap { $0.exercises ?? [] }.flatMap { $0.sets ?? [] }.filter(\.isPR).count }
    private var volume: Double {
        completedThisWeek.flatMap { $0.exercises ?? [] }.flatMap { $0.sets ?? [] }.reduce(0) { total, set in
            total + TrainingMath.volumeKg(weightKg: set.weightKg ?? 0, reps: set.reps ?? 0, kind: set.type, latestBodyweightKg: nil)
        }
    }
    private var weeklySetBars: [Double] {
        let calendar = Calendar.current
        let counts = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date()
            return sessions.filter { $0.status == .completed && calendar.isDate($0.startedAt, inSameDayAs: date) }.reduce(0) { $0 + $1.completedSetCount }
        }
        let maxCount = max(counts.max() ?? 0, 1)
        return counts.map { max(0.08, Double($0) / Double(maxCount)) }
    }
    private var streakWeeks: Int {
        let calendar = Calendar.current
        var streak = 0
        for offset in 0..<52 {
            guard let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()) else { continue }
            let hasWorkout = sessions.contains { $0.status == .completed && calendar.isDate($0.startedAt, equalTo: week, toGranularity: .weekOfYear) }
            if hasWorkout { streak += 1 } else if offset > 0 { break }
        }
        return max(streak, 1)
    }
}

struct RecommendedCard: View {
    let routines: [Routine]
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Recommended next")
            if let routine = routines.filter({ $0.archivedAt == nil }).first {
                Text(routine.name).font(RSTheme.mono(17, weight: .bold))
                Text("Least recently performed · balances weekly sets").font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                Button("Start", action: action).buttonStyle(RSButtonStyle(kind: .primary))
            } else {
                EmptyStateCard(title: "Build a routine to get session recommendations", message: "Your next-session card unlocks after a saved routine.", actionTitle: "New routine", action: action)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hairlineCard()
    }
}

struct BodyCard: View {
    let metrics: [BodyMetric]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Body")
                Spacer()
                HStack(spacing: 2) {
                    RSChip(text: "W", selected: true)
                    RSChip(text: "M")
                    RSChip(text: "Y")
                }
            }
            if metrics.count < 2 {
                EmptyStateCard(title: "Log a bodyweight to start tracking", message: "Weight and body-fat trends appear here once you have measurements.")
            } else {
                HStack {
                    Text("WEIGHT \(metrics.first!.bodyweightKg, specifier: "%.1f") kg").font(RSTheme.mono(11, weight: .bold)).foregroundStyle(RSTheme.signal)
                    Spacer()
                    Text("BODY FAT \(metrics.first?.bodyFatPct ?? 0, specifier: "%.1f")%").font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary)
                }
                LineTrendChart(values: metrics.prefix(8).reversed().map(\.bodyweightKg))
                Text("Swipe chart to view previous weeks").font(RSTheme.mono(10)).foregroundStyle(RSTheme.textTertiary)
            }
        }
        .hairlineCard()
    }
}

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var mode = "Calendar"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ScreenTitle(text: "History")
                    Picker("Mode", selection: $mode) {
                        Text("Calendar").tag("Calendar")
                        Text("List").tag("List")
                    }
                    .pickerStyle(.segmented)
                    .tint(RSTheme.signal)

                    if mode == "Calendar" { CalendarGrid(sessions: sessions) }
                    CompletedSessionList(sessions: sessions)
                }
                .padding()
            }
            .navigationTitle("")
            .appBackground()
        }
    }
}

struct CalendarGrid: View {
    let sessions: [WorkoutSession]
    private let calendar = Calendar.current
    var body: some View {
        VStack(alignment: .leading) {
            Eyebrow(text: "Month grid")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { Text($0).font(RSTheme.mono(10, weight: .bold)).foregroundStyle(RSTheme.textTertiary) }
                ForEach(monthDates, id: \.self) { date in
                    let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
                    let completed = sessions.contains { $0.status == .completed && calendar.isDate($0.startedAt, inSameDayAs: date) }
                    Text("\(calendar.component(.day, from: date))")
                        .font(RSTheme.mono(12))
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isCurrentMonth ? RSTheme.textPrimary : RSTheme.textTertiary)
                        .background(calendar.isDateInToday(date) ? RSTheme.signal.opacity(0.14) : RSTheme.surfaceInput)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(completed ? RSTheme.signal : .clear, style: StrokeStyle(lineWidth: 1, dash: [4,4])))
                }
            }
        }
        .hairlineCard()
    }

    private var monthDates: [Date] {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let mondayOffset = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: startOfMonth) ?? startOfMonth
        return (0..<35).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

struct CompletedSessionList: View {
    let sessions: [WorkoutSession]
    var completed: [WorkoutSession] { sessions.filter { $0.status == .completed } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Workouts")
            if completed.isEmpty {
                EmptyStateCard(title: "Your first session will appear here", message: "Finish a workout to populate history and charts.")
            } else {
                ForEach(completed) { session in
                    NavigationLink {
                        HistoricalSessionDetailView(session: session)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.name).font(RSTheme.mono(14, weight: .bold))
                                Text("\(session.completedSetCount) sets · \(session.startedAt.formatted(date: .abbreviated, time: .omitted))").font(RSTheme.mono(11)).foregroundStyle(RSTheme.textSecondary)
                            }
                            Spacer()
                            RSChip(text: "Edit")
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .hairlineCard()
    }
}

struct HistoricalSessionDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    @Bindable var session: WorkoutSession
    @State private var showingDelete = false

    var body: some View {
        Form {
            Section("Workout") {
                TextField("Name", text: $session.name)
                    .onSubmit(save)
                DatePicker("Started", selection: $session.startedAt)
                DatePicker("Ended", selection: Binding(get: { session.endedAt ?? session.startedAt }, set: { session.endedAt = $0 }), displayedComponents: [.date, .hourAndMinute])
                Text("\(session.completedSetCount) sets")
                    .foregroundStyle(.secondary)
            }

            ForEach((session.exercises ?? []).sorted { $0.order < $1.order }) { exercise in
                Section(exercise.exerciseName) {
                    ForEach((exercise.sets ?? []).sorted { $0.index < $1.index }) { set in
                        HistoricalSetEditRow(set: set, save: save)
                    }
                    .onDelete { offsets in
                        var sorted = (exercise.sets ?? []).sorted { $0.index < $1.index }
                        sorted.remove(atOffsets: offsets)
                        for (index, set) in sorted.enumerated() {
                            set.index = index + 1
                        }
                        exercise.sets = sorted
                        save()
                    }
                }
            }

            Section {
                Button("Recalculate records", action: save)
                Button("Delete workout", role: .destructive) { showingDelete = true }
            }
        }
        .navigationTitle(session.name)
        .toolbar {
            Button("Save", action: save)
        }
        .confirmationDialog("Delete this workout?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                store.deleteHistoricalSession(session, context: context, bodyweightKg: bodyMetrics.first?.bodyweightKg)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session, rebuilds PR history, and deletes the matching Apple Health workout if RepSetForge exported one.")
        }
    }

    private func save() {
        store.persistHistoricalChange(session: session, context: context, bodyweightKg: bodyMetrics.first?.bodyweightKg)
    }
}

struct HistoricalSetEditRow: View {
    @Bindable var set: SetEntry
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Set \(set.index)")
                    .font(RSTheme.mono(13, weight: .bold))
                Spacer()
                if set.isPR {
                    RSChip(text: "PR", selected: true)
                }
            }
            Picker("Type", selection: Binding(get: { set.type }, set: { set.type = $0; save() })) {
                ForEach(SetKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("kg", value: Binding(get: { set.weightKg ?? 0 }, set: { set.weightKg = $0; set.touchedWeight = true }), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                TextField("reps", value: Binding(get: { set.reps ?? 0 }, set: { set.reps = $0; set.touchedReps = true }), format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                TextField("RPE", value: Binding(get: { set.rpe ?? 0 }, set: { set.rpe = $0 > 0 ? $0 : nil }), format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
            }
            DatePicker("Completed", selection: Binding(get: { set.completedAt ?? Date() }, set: { set.completedAt = $0; save() }), displayedComponents: [.date, .hourAndMinute])
                .font(.caption)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historicalSetRow.\(set.index)")
    }
}

struct ProgressViewScreen: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ScreenTitle(text: "Progress")
                    ChartCard(title: "Weekly Volume", values: weeklyVolumeBars, insight: completed.count < 2 ? "Unlocks after 2 completed sessions." : "Volume reflects completed sets by week.")
                    ChartCard(title: "Consistency", values: consistencyBars, insight: completed.count < 4 ? "Session frequency appears here after four data points." : "\(completed.count) completed sessions in history.")
                    ChartCard(title: "Muscle Distribution", values: muscleDistributionBars, insight: completed.isEmpty ? "Muscle balance appears after your first workout." : "Distribution is calculated from completed set counts.")
                    ChartCard(title: "Exercise Trends", values: exerciseTrendBars, insight: exerciseTrendBars.count < 4 ? "Per-exercise e1RM trends unlock after four matching sessions." : "Best estimated 1RM trend for your most-used exercise.")
                }
                .padding()
            }
            .navigationTitle("")
            .appBackground()
        }
    }

    private var completed: [WorkoutSession] { sessions.filter { $0.status == .completed } }
    private var calendar: Calendar { .current }

    private var weeklyVolumeBars: [Double] {
        let values = (0..<8).map { offset -> Double in
            guard let week = calendar.date(byAdding: .weekOfYear, value: offset - 7, to: Date()) else { return 0 }
            return completed
                .filter { calendar.isDate($0.startedAt, equalTo: week, toGranularity: .weekOfYear) }
                .flatMap { $0.exercises ?? [] }
                .flatMap { $0.sets ?? [] }
                .reduce(0) { $0 + TrainingMath.volumeKg(weightKg: $1.weightKg ?? 0, reps: $1.reps ?? 0, kind: $1.type, latestBodyweightKg: nil) }
        }
        return normalized(values)
    }

    private var consistencyBars: [Double] {
        normalized((0..<8).map { offset -> Double in
            guard let week = calendar.date(byAdding: .weekOfYear, value: offset - 7, to: Date()) else { return 0 }
            return Double(completed.filter { calendar.isDate($0.startedAt, equalTo: week, toGranularity: .weekOfYear) }.count)
        })
    }

    private var muscleDistributionBars: [Double] {
        let groups = MuscleGroup.allCases.map { group in
            Double(completed.flatMap { $0.exercises ?? [] }.filter { $0.primaryMuscle == group }.reduce(0) { $0 + $1.completedSets })
        }
        return normalized(groups)
    }

    private var exerciseTrendBars: [Double] {
        let exercises = completed.flatMap { $0.exercises ?? [] }
        guard let targetName = Dictionary(grouping: exercises, by: \.exerciseName).max(by: { $0.value.count < $1.value.count })?.key else { return [0.08, 0.08, 0.08, 0.08] }
        let values = completed.reversed().compactMap { session -> Double? in
            session.exercises?.first(where: { $0.exerciseName == targetName })?.sets?.compactMap {
                guard let weight = $0.weightKg, let reps = $0.reps else { return nil }
                return TrainingMath.e1RM(weightKg: weight, reps: reps)
            }.max()
        }
        return normalized(values)
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let maxValue = max(values.max() ?? 0, 1)
        return values.map { max(0.08, $0 / maxValue) }
    }
}

struct ChartCard: View {
    let title: String
    let values: [Double]
    let insight: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
            LineTrendChart(values: values)
            Text(insight).font(RSTheme.mono(13, weight: .semibold)).foregroundStyle(RSTheme.textSecondary)
        }
        .hairlineCard()
    }
}
