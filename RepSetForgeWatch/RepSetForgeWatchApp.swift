import SwiftUI

@main
struct RepSetForgeWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = WatchTab.workout
    @State private var session = WatchWorkoutSession.sample
    @State private var confirmation: CompletionConfirmation?

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchWorkoutView(session: $session, confirmation: $confirmation, reduceMotion: reduceMotion)
                .tag(WatchTab.workout)
                .accessibilityIdentifier("watch.tab.workout")
            WatchRestView(rest: $session.rest, reduceMotion: reduceMotion)
                .tag(WatchTab.rest)
                .accessibilityIdentifier("watch.tab.rest")
            WatchVitalsView(vitals: session.vitals, summary: session.summary)
                .tag(WatchTab.vitals)
                .accessibilityIdentifier("watch.tab.vitals")
        }
        .tabViewStyle(.verticalPage)
        .containerBackground(.black, for: .navigation)
        .overlay(alignment: .bottom) {
            if let confirmation {
                CompletionToast(confirmation: confirmation)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("watch.completion.feedback")
            }
        }
    }
}

private enum WatchTab: Hashable {
    case workout
    case rest
    case vitals
}

private struct WatchWorkoutView: View {
    @Binding var session: WatchWorkoutSession
    @Binding var confirmation: CompletionConfirmation?
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WatchLabel("WORKOUT")
            Text(session.exerciseName.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack {
                Text("SET \(session.currentSetNumber)/\(session.sets.count)")
                Spacer()
                StatusPill(text: session.currentSet.isComplete ? "DONE" : "LIVE", isActive: !session.currentSet.isComplete)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            Text(session.currentSet.prescription)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .accessibilityLabel(session.currentSet.accessibilityPrescription)
            Text(session.currentSet.note)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button {
                completeCurrentSet()
            } label: {
                Label(session.currentSet.isComplete ? "Logged" : "Complete Set", systemImage: session.currentSet.isComplete ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .tint(session.currentSet.isComplete ? .green : .blue)
            .disabled(session.currentSet.isComplete)
            .accessibilityLabel(session.currentSet.isComplete ? "Current set logged" : "Complete current set")
            .accessibilityHint("Logs the set locally on this watch")
            .accessibilityIdentifier("watch.workout.completeSetButton")
        }
        .padding(.horizontal, 6)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: session.currentSet.isComplete)
    }

    private func completeCurrentSet() {
        guard !session.currentSet.isComplete else { return }
        let completedSet = session.currentSetNumber
        session.completeCurrentSet()
        confirmation = CompletionConfirmation(setNumber: completedSet)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if confirmation?.setNumber == completedSet {
                confirmation = nil
            }
        }
    }
}

private struct WatchRestView: View {
    @Binding var rest: WatchRestState
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 8) {
            WatchLabel("REST")
            Text(rest.timeText)
                .font(.system(size: 39, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(rest.isSkipped ? Color.secondary : Color.green)
                .accessibilityLabel(rest.accessibilityTime)
                .accessibilityIdentifier("watch.rest.remainingTime")
            Text(rest.subtitle)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            ProgressView(value: rest.progress)
                .tint(rest.isSkipped ? .gray : .green)
                .accessibilityLabel("Rest progress")
                .accessibilityValue("\(Int(rest.progress * 100)) percent")
            HStack(spacing: 6) {
                Button {
                    rest.extend(by: 30)
                } label: {
                    Label("+30", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Extend rest by 30 seconds")
                .accessibilityIdentifier("watch.rest.extendButton")

                Button {
                    rest.skip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)
                .accessibilityLabel("Skip rest")
                .accessibilityIdentifier("watch.rest.skipButton")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 6)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: rest.remainingSeconds)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: rest.status)
    }
}

private struct WatchVitalsView: View {
    let vitals: WatchVitals
    let summary: WorkoutSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                WatchLabel("VITALS")
                Spacer()
                StatusPill(text: vitals.isStale ? "STALE" : "LIVE", isActive: !vitals.isStale)
                    .accessibilityIdentifier("watch.vitals.staleBadge")
            }
            WatchMetricRow(label: "HEART", value: vitals.heartRateText, isStale: vitals.isStale)
            WatchMetricRow(label: "ENERGY", value: "\(vitals.activeEnergyKcal) KCAL", isStale: vitals.isStale)
            WatchMetricRow(label: "ELAPSED", value: summary.elapsedText, isStale: false)
            WatchMetricRow(label: "SETS", value: "\(summary.completedSets)/\(summary.totalSets)", isStale: false)
            WatchMetricRow(label: "VOLUME", value: "\(summary.volumeKg) KG", isStale: false)
            Text(vitals.caption)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .accessibilityIdentifier("watch.vitals.caption")
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .contain)
    }
}

private struct CompletionToast: View {
    let confirmation: CompletionConfirmation

    var body: some View {
        Label("Set \(confirmation.setNumber) logged", systemImage: "checkmark.circle.fill")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.green.opacity(0.24), in: Capsule())
            .foregroundStyle(.green)
            .accessibilityLabel("Set \(confirmation.setNumber) logged")
    }
}

private struct WatchLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct StatusPill: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((isActive ? Color.green : Color.secondary).opacity(0.18), in: Capsule())
            .foregroundStyle(isActive ? Color.green : Color.secondary)
    }
}

private struct WatchMetricRow: View {
    let label: String
    let value: String
    let isStale: Bool

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(isStale ? Color.secondary : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)\(isStale ? ", stale" : "")")
        .accessibilityIdentifier("watch.vitals.\(label.lowercased())")
    }
}

private struct WatchWorkoutSession {
    var exerciseName: String
    var sets: [WorkoutSet]
    var rest: WatchRestState
    var vitals: WatchVitals
    var elapsedSeconds: Int

    var currentSetIndex: Int {
        sets.firstIndex { !$0.isComplete } ?? max(sets.count - 1, 0)
    }

    var currentSetNumber: Int {
        currentSetIndex + 1
    }

    var currentSet: WorkoutSet {
        sets[currentSetIndex]
    }

    var summary: WorkoutSummary {
        let completed = sets.filter(\.isComplete)
        let volume = completed.reduce(0) { $0 + ($1.weightKg * $1.reps) }
        return WorkoutSummary(
            elapsedSeconds: elapsedSeconds,
            completedSets: completed.count,
            totalSets: sets.count,
            volumeKg: volume
        )
    }

    mutating func completeCurrentSet() {
        guard sets.indices.contains(currentSetIndex) else { return }
        sets[currentSetIndex].isComplete = true
        rest.reset(forNextSet: min(currentSetIndex + 1, sets.count))
    }

    static let sample = WatchWorkoutSession(
        exerciseName: "Bench Press",
        sets: [
            WorkoutSet(weightKg: 135, reps: 8, rpe: 8, previous: "100x8", isComplete: false),
            WorkoutSet(weightKg: 135, reps: 8, rpe: 8, previous: "100x8", isComplete: false),
            WorkoutSet(weightKg: 130, reps: 10, rpe: 9, previous: "97.5x10", isComplete: false)
        ],
        rest: WatchRestState(totalSeconds: 150, remainingSeconds: 94, nextSetNumber: 2),
        vitals: WatchVitals(
            heartRate: 118,
            activeEnergyKcal: 328,
            lastUpdated: Date(timeIntervalSinceNow: -86)
        ),
        elapsedSeconds: 3120
    )
}

private struct WorkoutSet: Identifiable {
    let id = UUID()
    let weightKg: Int
    let reps: Int
    let rpe: Int
    let previous: String
    var isComplete: Bool

    var prescription: String {
        "\(weightKg)KG x \(reps)"
    }

    var accessibilityPrescription: String {
        "\(weightKg) kilograms for \(reps) reps"
    }

    var note: String {
        "@\(rpe) RPE - PREV \(previous)"
    }
}

private struct WatchRestState {
    enum Status: Equatable {
        case active
        case extended
        case skipped
    }

    var totalSeconds: Int
    var remainingSeconds: Int
    var nextSetNumber: Int
    var status: Status = .active

    var isSkipped: Bool {
        status == .skipped
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return min(1, max(0, Double(totalSeconds - remainingSeconds) / Double(totalSeconds)))
    }

    var timeText: String {
        "\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))"
    }

    var accessibilityTime: String {
        if isSkipped { return "Rest skipped" }
        return "\(remainingSeconds / 60) minutes \(remainingSeconds % 60) seconds remaining"
    }

    var subtitle: String {
        switch status {
        case .active:
            return "OF \(formatted(totalSeconds)) - NEXT SET \(nextSetNumber)"
        case .extended:
            return "EXTENDED - NEXT SET \(nextSetNumber)"
        case .skipped:
            return "SKIPPED - NEXT SET READY"
        }
    }

    mutating func extend(by seconds: Int) {
        totalSeconds += seconds
        remainingSeconds += seconds
        status = .extended
    }

    mutating func skip() {
        remainingSeconds = 0
        status = .skipped
    }

    mutating func reset(forNextSet nextSet: Int) {
        totalSeconds = 150
        remainingSeconds = 150
        nextSetNumber = nextSet
        status = .active
    }

    private func formatted(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct WatchVitals {
    var heartRate: Int?
    var activeEnergyKcal: Int
    var lastUpdated: Date

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 60
    }

    var heartRateText: String {
        guard let heartRate else { return "-- BPM" }
        return "\(heartRate) BPM"
    }

    var caption: String {
        if isStale {
            return "LAST UPDATE \(relativeAge.uppercased()) AGO"
        }
        return "UPDATED NOW"
    }

    private var relativeAge: String {
        let seconds = max(0, Int(Date().timeIntervalSince(lastUpdated)))
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }
}

private struct WorkoutSummary {
    let elapsedSeconds: Int
    let completedSets: Int
    let totalSets: Int
    let volumeKg: Int

    var elapsedText: String {
        let minutes = elapsedSeconds / 60
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }
}

private struct CompletionConfirmation: Equatable {
    let setNumber: Int
}

#Preview {
    WatchRootView()
}
