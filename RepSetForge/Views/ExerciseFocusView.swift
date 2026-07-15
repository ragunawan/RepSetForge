import SwiftUI
import SwiftData
import UIKit

/// The core logging surface (dev spec §3, mockup frame 2b) — "the product
/// lives or dies here." One exercise per page; the caller (`ActiveWorkoutView`)
/// hosts one of these per `SessionExercise` inside a paged `TabView`.
///
/// Superset paging and the exercise `⋯` menu (Reorder/Replace/Remove) are
/// still TODO.md work — this covers the telemetry header, chart, coaching
/// prompt, the set table itself, and (when the session came from a routine)
/// the progression panel.
struct ExerciseFocusView: View {
    let session: WorkoutSession
    var sessionExercise: SessionExercise
    let restTimer: RestTimerManager
    let onOpenIndex: () -> Void
    let onMinimize: () -> Void
    var pageNumber: Int
    var pageCount: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fetched unfiltered and matched against the exercise in-memory — SwiftData's
    // #Predicate macro has historically been fragile across multi-hop optional
    // relationship chains (sessionExercise?.exercise?.id), and this can't be
    // verified against a real compiler in this environment. Revisit as a
    // #Predicate filter once that's been confirmed safe on a real build.
    @Query private var allSessions: [WorkoutSession]
    @Query private var allSetEntries: [SetEntry]
    @Query private var allPRRecords: [PRRecord]

    @State private var isChartExpanded = true
    @State private var hasAutoCollapsedChart = false
    @State private var isPresentingProgressionPanel = false

    @AppStorage(AppSettingsKeys.defaultRestSeconds) private var defaultRestSeconds = 90

    private var sets: [SetEntry] {
        sessionExercise.setEntries.sorted { $0.index < $1.index }
    }

    var body: some View {
        List {
            headerBlock
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.horizontal, 14)
                .padding(.top, 8)

            ForEach(Array(sets.enumerated()), id: \.element.id) { offset, set in
                SetRowView(
                    set: set,
                    displayIndex: displayIndex(for: set, in: sets),
                    exerciseName: sessionExercise.exercise?.name ?? "Exercise",
                    totalSetsInExercise: sets.count,
                    ghostWeight: ghostValues[offset].weight,
                    ghostReps: ghostValues[offset].reps,
                    ghostRPE: ghostValues[offset].rpe,
                    onComplete: { handleCompletion(of: set) }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(set)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Text("+ Add set")
                    .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 90, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RepSetForgeTheme.Colors.surface)
        .safeAreaInset(edge: .bottom) {
            bottomPill
        }
        .sheet(isPresented: $isPresentingProgressionPanel) {
            if let rule = sessionExercise.routineItem?.progressionRule {
                ProgressionPanelView(sessionExercise: sessionExercise, rule: rule)
            }
        }
    }

    // MARK: - Header block

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            telemetryHeader
            identityRow
            if let exercise = sessionExercise.exercise {
                if isChartExpanded {
                    chartBlock(exercise: exercise)
                } else {
                    collapsedChartRow
                }
            }
            if let prompt = coachingPrompt {
                promptBanner(prompt)
            }
        }
    }

    private var telemetryHeader: some View {
        TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(session.startedAt)
            let rest = restTimer.cumulativeRest(now: context.date)
            let work = max(0, elapsed - rest)
            let allSets = session.sessionExercises.flatMap(\.setEntries)
            let totalSets = allSets.count
            let completedSets = allSets.filter { $0.completedAt != nil }.count
            let percent = totalSets > 0 ? Int((Double(completedSets) / Double(totalSets) * 100).rounded()) : 0

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("SESSION:")
                    Spacer()
                    Text(Self.formatDuration(elapsed)).fontWeight(.semibold)
                }
                HStack {
                    Text("WORK: \(Self.formatDuration(work))")
                    Spacer()
                    Text("REST: \(Self.formatDuration(rest))")
                }
                HStack {
                    Text("\(percent)%")
                    Spacer()
                    Text("SET \(completedSets)/\(totalSets)")
                }
                ProgressView(value: totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0)
                    .tint(RepSetForgeTheme.Colors.signal)
            }
            .font(RepSetForgeTheme.Typography.mono(11, weight: .semibold))
            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
    }

    private var identityRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(RepSetForgeTheme.Colors.surfaceInput)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(RepSetForgeTheme.Typography.mono(16, weight: .bold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionExercise.exercise?.name ?? "Exercise")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                if !muscleDetail.isEmpty {
                    Text(muscleDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }
            }
            Spacer()
        }
    }

    private var initials: String {
        let words = (sessionExercise.exercise?.name ?? "").split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private var muscleDetail: String {
        guard let exercise = sessionExercise.exercise else { return "" }
        let all = exercise.muscleGroups.map(\.displayName) + exercise.secondaryMuscles.map(\.displayName)
        return all.joined(separator: " · ")
    }

    // MARK: - Chart

    private func chartBlock(exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ExerciseTrendChart(points: trendPoints)
            HStack(spacing: 6) {
                if let oneRM = trendPoints.last?.e1RM {
                    chip("1RM \(Self.formatWeight(oneRM)) kg")
                }
                if let bestWeightPR = allPRRecords.first(where: { $0.exercise?.id == exercise.id && $0.kind == .bestWeight }) {
                    chip("PR \(Self.formatWeight(bestWeightPR.value)) kg")
                }
            }
        }
    }

    private var collapsedChartRow: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isChartExpanded = true }
        } label: {
            HStack {
                Text("CHART")
                    .font(RepSetForgeTheme.Typography.mono(9, weight: .bold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                Spacer()
                if let oneRM = trendPoints.last?.e1RM {
                    Text("1RM \(Self.formatWeight(oneRM))")
                        .font(RepSetForgeTheme.Typography.mono(12))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(RepSetForgeTheme.Typography.mono(10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RepSetForgeTheme.Colors.surfaceInput, in: Capsule())
            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
    }

    private var trendPoints: [ExerciseTrendChart.Point] {
        guard let exerciseID = sessionExercise.exercise?.id else { return [] }
        let qualifying = ExerciseHistoryService.qualifyingSets(exerciseID: exerciseID, in: allSetEntries)
        return ExerciseHistoryService.trendPoints(from: qualifying)
    }

    // MARK: - Coaching prompt

    private var coachingPrompt: (weight: Decimal, reps: Int, rpe: Double?)? {
        guard let last = previousSessionSets.last(where: { $0.type == .working && $0.weightKg != nil && $0.reps != nil }),
              let weight = last.weightKg, let reps = last.reps else { return nil }
        return (weight, reps, last.rpe)
    }

    private func promptBanner(_ prompt: (weight: Decimal, reps: Int, rpe: Double?)) -> some View {
        Button {
            applyPromptToPendingSets(prompt)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("↑")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same as last session.")
                    Text("Target: ≥ \(Self.formatWeight(prompt.weight)) kg × \(prompt.reps)\(prompt.rpe.map { " @ \(Int($0)) RPE" } ?? "")")
                        .foregroundStyle(RepSetForgeTheme.Colors.signal)
                }
            }
            .font(RepSetForgeTheme.Typography.mono(12))
            .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RepSetForgeTheme.Colors.signalDim, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RepSetForgeTheme.Colors.signal, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func applyPromptToPendingSets(_ prompt: (weight: Decimal, reps: Int, rpe: Double?)) {
        for set in sets where set.completedAt == nil {
            set.weightKg = prompt.weight
            set.reps = prompt.reps
            set.rpe = prompt.rpe
        }
    }

    // MARK: - Ghost values / previous session

    private var ghostValues: [(weight: Decimal?, reps: Int?, rpe: Double?)] {
        var results: [(Decimal?, Int?, Double?)] = []
        let previous = previousSessionSets
        for (i, s) in sets.enumerated() {
            if i == 0 {
                let match = previous.first
                results.append((match?.weightKg, match?.reps, match?.rpe))
            } else {
                let priorSet = sets[i - 1]
                let priorGhost = results[i - 1]
                results.append((
                    priorSet.weightKg ?? priorGhost.0,
                    priorSet.reps ?? priorGhost.1,
                    priorSet.rpe ?? priorGhost.2
                ))
            }
        }
        return results
    }

    private var previousSessionSets: [SetEntry] {
        guard let exerciseID = sessionExercise.exercise?.id else { return [] }
        let candidates = allSessions
            .filter { $0.id != session.id && $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
        for candidate in candidates {
            if let match = candidate.sessionExercises.first(where: { $0.exercise?.id == exerciseID }) {
                return match.setEntries.sorted { $0.index < $1.index }
            }
        }
        return []
    }

    private func displayIndex(for set: SetEntry, in sets: [SetEntry]) -> Int {
        let sameType = sets.filter { $0.type == set.type }
        return (sameType.firstIndex(where: { $0.id == set.id }) ?? 0) + 1
    }

    // MARK: - Actions

    private func handleCompletion(of set: SetEntry) {
        if let exercise = sessionExercise.exercise {
            let existing = allPRRecords.filter { $0.exercise?.id == exercise.id }
            let newRecords = PersonalRecordService.evaluate(set: set, exercise: exercise, existingRecords: existing, context: modelContext)
            if !newRecords.isEmpty {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }

        if !hasAutoCollapsedChart {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isChartExpanded = false }
            hasAutoCollapsedChart = true
        }

        restTimer.start(duration: TimeInterval(defaultRestSeconds))

        if set.index == sets.map(\.index).max() {
            addSet()
        }
    }

    private func addSet() {
        let nextIndex = (sets.map(\.index).max() ?? -1) + 1
        let newSet = SetEntry(index: nextIndex)
        newSet.sessionExercise = sessionExercise
        modelContext.insert(newSet)
    }

    private func delete(_ set: SetEntry) {
        modelContext.delete(set)
    }

    // MARK: - Bottom pill

    /// Only enabled when this session came from a routine with a
    /// `ProgressionRule` attached — an ad-hoc workout has no ladder to show.
    private var progButton: some View {
        let isAvailable = sessionExercise.routineItem?.progressionRule != nil
        return Button {
            isPresentingProgressionPanel = true
        } label: {
            Text("PROG")
                .font(RepSetForgeTheme.Typography.mono(10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RepSetForgeTheme.Colors.surfaceInput, in: Capsule())
                .foregroundStyle(isAvailable ? RepSetForgeTheme.Colors.textSecondary : RepSetForgeTheme.Colors.textTertiary)
                .opacity(isAvailable ? 1 : 0.4)
        }
        .disabled(!isAvailable)
    }

    private var bottomPill: some View {
        VStack(spacing: 8) {
            if restTimer.isResting {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    RestTimerPill(restTimer: restTimer, now: context.date)
                }
                .padding(.horizontal, 10)
            }

            HStack {
                Button {
                    onMinimize()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                }

                progButton

                Spacer()

                Button {
                    onOpenIndex()
                } label: {
                    Text("\(pageNumber) / \(pageCount)")
                        .font(RepSetForgeTheme.Typography.mono(12, weight: .semibold))
                        .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    .opacity(0.4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RepSetForgeTheme.Colors.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(RepSetForgeTheme.Colors.hairline, lineWidth: 1))
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Formatting

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let clamped = max(0, Int(interval))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formatWeight(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
