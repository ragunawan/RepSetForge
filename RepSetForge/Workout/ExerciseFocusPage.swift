import SwiftUI
import SwiftData

/// One page of the carousel (§3): a single exercise, or a superset/circuit
/// group rendered as stacked full-bleed member sections (hairline-divided,
/// each with its own set table). Identity row, collapsible chart (member
/// chips when grouped), coaching prompt, set table, add-set, finish.
struct ExerciseFocusPage: View {
    @Bindable var vm: WorkoutViewModel
    let pageIndex: Int
    let members: [SessionExercise]
    var onFinish: () -> Void = {}
    /// Which member's chart shows (§3: first member's chart + chips to switch).
    @State private var chartMember = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if members.count > 1 {
                        supersetHeader
                        memberChips
                    }
                    if let chartEx = members.indices.contains(chartMember) ? members[chartMember] : members.first {
                        ChartSection(vm: vm, pageIndex: pageIndex, exercise: chartEx)
                        Divider().overlay(DT.Colors.hairline)
                    }

                    ForEach(Array(members.enumerated()), id: \.element.persistentModelID) { m, ex in
                        memberSection(m: m, ex: ex, proxy: proxy)
                    }

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
    }

    @ViewBuilder
    private func memberSection(m: Int, ex: SessionExercise, proxy: ScrollViewProxy) -> some View {
        let isFinal = m == members.count - 1
        VStack(alignment: .leading, spacing: 0) {
            identityRow(ex)
            Divider().overlay(DT.Colors.hairline)

            CoachingPromptBanner(vm: vm, exercise: ex)

            SetTableView(vm: vm, exercise: ex,
                         // §3 superset rest: members before the last start no
                         // timer; the round's final member starts group rest.
                         startsRestOnComplete: members.count == 1 || isFinal,
                         onSetCompleted: {
                             guard members.count > 1, !isFinal else { return }
                             withAnimation(DT.Motion.stateChange) {
                                 proxy.scrollTo(members[m + 1].persistentModelID, anchor: .top)
                             }
                         })

            Button {
                vm.addSet(to: ex)
            } label: {
                Text("+ Add set")
                    .font(DT.Type.secondary.weight(.semibold))
                    .foregroundStyle(DT.Colors.textSecondary)
                    .frame(minHeight: DT.Touch.minimum)
            }
            .padding(.horizontal, DT.Spacing.s16 + 2)
        }
        .id(ex.persistentModelID)
        if !isFinal {
            Divider().overlay(DT.Colors.hairline)
                .padding(.vertical, DT.Spacing.s4)
        }
    }

    private var supersetHeader: some View {
        Text("SUPERSET · \(members.count) EXERCISES")
            .font(DT.Type.eyebrow)
            .foregroundStyle(DT.Colors.signal)
            .padding(.horizontal, DT.Spacing.s16 + 2)
            .padding(.top, DT.Spacing.s8)
    }

    private var memberChips: some View {
        HStack(spacing: DT.Spacing.s8 - 2) {
            ForEach(Array(members.enumerated()), id: \.element.persistentModelID) { m, ex in
                Button {
                    chartMember = m
                } label: {
                    Text(ex.exercise?.name ?? "Exercise")
                        .font(DT.Type.eyebrow)
                        .lineLimit(1)
                        .foregroundStyle(chartMember == m ? DT.Colors.signal : DT.Colors.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(chartMember == m ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(chartMember == m ? DT.Colors.signal : DT.Colors.hairline))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DT.Spacing.s16 + 2)
        .padding(.vertical, DT.Spacing.s4)
    }

    private func identityRow(_ exercise: SessionExercise) -> some View {
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
                Text(muscleDetail(exercise))
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

    private func muscleDetail(_ exercise: SessionExercise) -> String {
        let e = exercise.exercise
        let parts = ([e?.muscleGroups.first].compactMap { $0 }) + (e?.secondaryMuscles ?? [])
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

/// §3.4 coaching prompt banner: plain-language trigger + explicit mono target.
/// Tap applies to pending sets. On a superset page each member shows its own
/// banner (per-member targets stacked).
struct CoachingPromptBanner: View {
    var vm: WorkoutViewModel
    let exercise: SessionExercise

    var body: some View {
        // Phase 4 wires ProgressionEngine.currentLevel here (single source of truth).
        if let target = currentTarget {
            Button {
                vm.applyTarget(exercise: exercise,
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
