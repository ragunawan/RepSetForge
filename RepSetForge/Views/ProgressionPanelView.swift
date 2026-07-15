import SwiftUI
import SwiftData

/// dev spec §3 "Progression panel", mockup frame 2c. Only reachable when the
/// session exercise came from a routine with a `ProgressionRule` attached
/// (`SessionExercise.routineItem`) — ad-hoc workouts have nothing to show
/// here. The rule editor rows are read-only for now (tap-to-edit isn't
/// built yet — TODO.md); this covers ladder generation and completion
/// tracking, the harder half.
struct ProgressionPanelView: View {
    let sessionExercise: SessionExercise
    let rule: ProgressionRule

    @Environment(\.dismiss) private var dismiss

    // Fetched unfiltered and matched in-memory — see ExerciseFocusView's
    // note on relationship-#Predicate risk in this environment.
    @Query private var allSetEntries: [SetEntry]

    private var historicalSets: [SetEntry] {
        guard let exerciseID = sessionExercise.exercise?.id else { return [] }
        return allSetEntries.filter { $0.sessionExercise?.exercise?.id == exerciseID }
    }

    private var baseWeight: Decimal {
        ProgressionLadderService.baseWeight(from: historicalSets)
            ?? sessionExercise.setEntries.compactMap(\.weightKg).first
            ?? 20
    }

    private var levels: [ProgressionLadderService.Level] {
        ProgressionLadderService.ladder(rule: rule, baseWeight: baseWeight, historicalSets: historicalSets)
    }

    private var currentLevelID: String? {
        ProgressionLadderService.currentLevel(in: levels)?.id
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Progression rule") {
                    ruleRow("Rep range", "\(rule.repRangeLow)–\(rule.repRangeHigh)")
                    ruleRow("RPE", "≤ \(Self.formatRPE(rule.maxQualifyingRPE))")
                    ruleRow("Sets per session", "≥ \(rule.qualifyingSetsRequired)")
                    ruleRow("Weight increment", "+\(Self.formatDecimal(rule.incrementKg)) kg")
                }
                .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)

                Section("Ladder") {
                    ForEach(levels) { level in
                        levelRow(level, isCurrent: level.id == currentLevelID)
                    }
                }
                .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle(sessionExercise.exercise?.name ?? "Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func ruleRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(RepSetForgeTheme.Typography.mono(13, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
    }

    private func levelRow(_ level: ProgressionLadderService.Level, isCurrent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Self.formatDecimal(level.weightKg)) kg × \(level.reps)")
                    .font(RepSetForgeTheme.Typography.mono(14, weight: .semibold))
                    .foregroundStyle(level.isComplete ? RepSetForgeTheme.Colors.textTertiary : RepSetForgeTheme.Colors.textPrimary)
                Text(levelSubtitle(level, isCurrent: isCurrent))
                    .font(RepSetForgeTheme.Typography.mono(11))
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
            }
            Spacer()
            if level.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RepSetForgeTheme.Colors.signal)
            }
        }
        .padding(.vertical, level.isComplete && !isCurrent ? 2 : 4)
        .opacity(level.isComplete && !isCurrent ? 0.55 : 1)
        .listRowBackground(isCurrent ? RepSetForgeTheme.Colors.signalDim : RepSetForgeTheme.Colors.surfaceRaised)
    }

    private func levelSubtitle(_ level: ProgressionLadderService.Level, isCurrent: Bool) -> String {
        var parts = ["e1RM \(Self.formatDecimal(level.estimatedOneRepMax)) kg"]
        if level.isLevelUp { parts.append("level up") }
        if isCurrent { parts.append("current") }
        return parts.joined(separator: " · ")
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func formatRPE(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
