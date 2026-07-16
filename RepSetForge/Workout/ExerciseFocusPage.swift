import SwiftUI
import SwiftData

/// One exercise per page (§3): identity row, collapsible chart, coaching
/// prompt, set table, add-set, finish. Full-bleed — hairline dividers only.
struct ExerciseFocusPage: View {
    @Bindable var vm: WorkoutViewModel
    let pageIndex: Int
    let exercise: SessionExercise
    var onFinish: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identityRow
                Divider().overlay(DT.Colors.hairline)

                ChartSection(vm: vm, pageIndex: pageIndex, exercise: exercise)
                Divider().overlay(DT.Colors.hairline)

                CoachingPromptBanner(vm: vm, pageIndex: pageIndex, exercise: exercise)

                SetTableView(vm: vm, pageIndex: pageIndex, exercise: exercise)

                Button {
                    vm.addSet(to: exercise)
                } label: {
                    Text("+ Add set")
                        .font(DT.Type.secondary.weight(.semibold))
                        .foregroundStyle(DT.Colors.textSecondary)
                        .frame(minHeight: DT.Touch.minimum)
                }
                .padding(.horizontal, DT.Spacing.s16 + 2)

                Button(action: onFinish) {
                    Text("Finish workout")
                        .font(DT.Type.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: DT.Touch.minimum)
                        .background(DT.Colors.surfaceInput)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card + 2))
                        .overlay(RoundedRectangle(cornerRadius: DT.Radius.card + 2)
                            .strokeBorder(DT.Colors.hairline))
                }
                .padding(.horizontal, DT.Spacing.s16 + 2)
                .padding(.vertical, DT.Spacing.s8)
            }
            .padding(.bottom, 140) // clear the bottom pill
        }
    }

    private var identityRow: some View {
        HStack(spacing: DT.Spacing.s12 - 2) {
            let initials = (exercise.exercise?.name ?? "?")
                .split(separator: " ").compactMap(\.first).prefix(2)
            Text(String(initials).uppercased())
                .font(DT.Type.secondary.weight(.bold))
                .foregroundStyle(DT.Colors.textSecondary)
                .frame(width: 42, height: 42)
                .background(DT.Colors.surfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.card)
                    .strokeBorder(DT.Colors.hairline))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise?.name ?? "Exercise")
                    .font(DT.Type.heading)
                    .tracking(-0.3)
                Text(muscleDetail)
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
            }
            Spacer()
            Menu {
                Button("Reorder") {}
                Button("Replace…") {}
                Button("Superset with…") {}
                Button("Remove", role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(DT.Colors.textTertiary)
                    .frame(width: DT.Touch.minimum, height: DT.Touch.minimum)
            }
        }
        .padding(.horizontal, DT.Spacing.s16 + 2)
        .padding(.vertical, DT.Spacing.s12 - 2)
    }

    private var muscleDetail: String {
        let e = exercise.exercise
        let parts = ([e?.muscleGroups.first].compactMap { $0 }) + (e?.secondaryMuscles ?? [])
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

/// §3.4 coaching prompt banner: plain-language trigger + explicit mono target.
/// Tap applies to pending sets. The target is fed from the ladder in Phase 4 —
/// until then it shows "same as last session" from ghost seeds.
struct CoachingPromptBanner: View {
    var vm: WorkoutViewModel
    let pageIndex: Int
    let exercise: SessionExercise

    var body: some View {
        // Phase 4 wires ProgressionEngine.currentLevel here (single source of truth).
        if let target = currentTarget {
            Button {
                vm.applyTarget(exercise: exercise, pageIndex: pageIndex,
                               weightKg: target.weightKg, reps: target.reps, rpe: target.rpe)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("↑ Same as last session — tap to apply")
                        .font(DT.Type.secondary)
                        .foregroundStyle(DT.Colors.textPrimary)
                    Text("Target: ≥ \(target.display)")
                        .font(DT.Type.secondary.weight(.semibold))
                        .foregroundStyle(DT.Colors.signal)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DT.Spacing.s16 + 2)
                .padding(.vertical, DT.Spacing.s8)
                .background(DT.Colors.signalDim)
                .overlay(alignment: .top) { DT.Colors.signal.frame(height: 1) }
                .overlay(alignment: .bottom) { DT.Colors.signal.frame(height: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    struct Target {
        var weightKg: Decimal
        var reps: Int
        var rpe: Double?
        var display: String {
            let w = NSDecimalNumber(decimal: weightKg).doubleValue
            let base = "\(w.formatted(.number.precision(.fractionLength(0...1)))) kg × \(reps)"
            if let rpe { return base + " @ \(rpe.formatted(.number.precision(.fractionLength(0...1)))) RPE" }
            return base
        }
    }

    private var currentTarget: Target? {
        // Seed from the first pending working set's resolved values.
        let sets = vm.orderedSets(exercise)
        guard let first = sets.first(where: { $0.type == .working }),
              let w = first.weightKg, let r = first.reps else { return nil }
        return Target(weightKg: w, reps: r, rpe: first.rpe)
    }
}
