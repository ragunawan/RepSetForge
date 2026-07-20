import SwiftUI
import SwiftData

/// §3 set table + §7a Dynamic Type tiers. The tier switch is this one view:
/// Tier 1 (≤ xxxLarge) six-column grid; Tier 2 (AX1) sheds Rest into the badge
/// row and shortens ghosts; Tier 3 (AX2+) stacked rows.
struct SetTableView: View {
    @Bindable var vm: WorkoutViewModel
    let exercise: SessionExercise
    /// False for non-final superset members: completing a set starts no rest
    /// timer (§3 — only the round's last member does).
    var startsRestOnComplete: Bool = true
    /// Fired after a completion commits (superset pages auto-scroll on it).
    var onSetCompleted: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]
    @State private var selection: FieldSelection?
    @State private var plateRow: Int?

    struct FieldSelection: Equatable {
        var row: Int
        var field: Field
        enum Field: String { case weight, reps, rpe, rest }
    }

    private var restSeconds: Int { vm.restSeconds(for: exercise) }

    var body: some View {
        let sets = vm.orderedSets(exercise)
        let resolved = vm.resolvedRows(exercise: exercise)

        VStack(spacing: 0) {
            if typeSize >= .accessibility2 {
                stackedRows(sets: sets, resolved: resolved)
            } else {
                gridHeader
                ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { i, set in
                    gridRow(i: i, set: set,
                            resolved: resolved.indices.contains(i) ? resolved[i] : .init(values: .init(), isGhost: false),
                            shedRest: typeSize == .accessibility1)
                }
            }
            if let sel = selection, sets.indices.contains(sel.row) {
                StepperAccessory(vm: vm, exercise: exercise,
                                 selection: sel, onClose: { selection = nil })
            }
        }
    }

    // MARK: Tier 1/2 grid

    private var gridHeader: some View {
        HStack(spacing: DT.Spacing.s4) {
            Text("#").frame(width: 34)
            Text("WEIGHT").frame(width: 64, alignment: .leading)
            Text("REPS").frame(width: 48, alignment: .leading)
            Text("RPE").frame(width: 40, alignment: .leading)
            if typeSize < .accessibility1 {
                Text("REST").frame(width: 52, alignment: .leading)
            }
            Spacer()
            Text("✓").frame(width: DT.Touch.setCompleteWidth)
        }
        .font(DT.Type.eyebrow)
        .foregroundStyle(DT.Colors.textTertiary)
        .padding(.horizontal, DT.Spacing.s8)
        .padding(.vertical, DT.Spacing.s4)
    }

    private func gridRow(i: Int, set: SetEntry, resolved: GhostResolver.Resolved, shedRest: Bool) -> some View {
        let done = set.completedAt != nil
        return VStack(spacing: 0) {
            HStack(spacing: DT.Spacing.s4) {
                typeBadge(set: set, showRestSuffix: shedRest)
                    .frame(width: shedRest ? nil : 34)
                fieldButton(i: i, field: .weight, width: 64,
                            text: weightText(resolved.values.weightKg), ghost: resolved.isGhost, done: done)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                        if resolved.values.weightKg != nil { plateRow = i }
                    })
                    .popover(isPresented: Binding(get: { plateRow == i },
                                                  set: { if !$0 { plateRow = nil } })) {
                        let p = profiles.first
                        PlateCalcView(
                            targetKg: NSDecimalNumber(decimal: resolved.values.weightKg ?? 0).doubleValue,
                            barKg: NSDecimalNumber(decimal: p?.barWeightKg ?? 20).doubleValue,
                            plates: p?.availablePlatesKg ?? [25, 20, 15, 10, 5, 2.5, 1.25])
                    }
                fieldButton(i: i, field: .reps, width: 48,
                            text: resolved.values.reps.map(String.init) ?? "—", ghost: resolved.isGhost, done: done)
                fieldButton(i: i, field: .rpe, width: 40,
                            text: rpeText(resolved.values.rpe), ghost: resolved.isGhost, done: done)
                if !shedRest {
                    fieldButton(i: i, field: .rest, width: 52,
                                text: restText(seconds: restSeconds), ghost: false, done: done)
                }
                Spacer()
                completeControl(i: i, set: set, resolved: resolved)
            }
            .padding(.horizontal, DT.Spacing.s8)
            .frame(minHeight: DT.Spacing.setRowHitTarget)
            .contentShape(Rectangle())
            .opacity(done ? 0.55 : 1)
            .background(vm.prFlashSetID == set.id ? DT.Colors.prDim : Color.clear)

            if set.isPR {
                HStack {
                    Spacer()
                    Text("PR")
                        .font(DT.Type.eyebrow.weight(.heavy))
                        .foregroundStyle(DT.Colors.pr)
                        .padding(.trailing, DT.Spacing.s16)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { vm.deleteSet(set, from: exercise) } label: { Text("Delete") }
        }
    }

    // MARK: Tier 3 — AX stacked set row (§7a frame C1)

    private func stackedRows(sets: [SetEntry], resolved: [GhostResolver.Resolved]) -> some View {
        ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { i, set in
            let r = resolved.indices.contains(i) ? resolved[i] : GhostResolver.Resolved(values: .init(), isGhost: false)
            VStack(alignment: .leading, spacing: DT.Spacing.s8) {
                if set.completedAt != nil {
                    // Completed cards collapse to one dimmed summary line.
                    Text("✓ \(weightText(set.weightKg)) kg × \(set.reps ?? 0)\(set.rpe.map { " · RPE \(rpeText($0))" } ?? "")")
                        .font(DT.Type.body)
                        .foregroundStyle(DT.Colors.textSecondary)
                        .monospacedDigit()
                } else {
                    HStack {
                        Text("SET \(set.index + 1) · \(set.type.rawValue.uppercased())")
                            .font(DT.Type.eyebrow)
                            .foregroundStyle(DT.Colors.textTertiary)
                        Spacer()
                    }
                    HStack(spacing: DT.Spacing.s8) {
                        stackedField(i: i, field: .weight, label: "WEIGHT", text: weightText(r.values.weightKg), ghost: r.isGhost)
                        stackedField(i: i, field: .reps, label: "REPS", text: r.values.reps.map(String.init) ?? "—", ghost: r.isGhost)
                    }
                    Button { selection = .init(row: i, field: .rpe) } label: {
                        Text("RPE \(rpeText(r.values.rpe)) · REST \(restText(seconds: restSeconds))")
                            .font(DT.Type.secondary)
                            .foregroundStyle(DT.Colors.textSecondary)
                            .monospacedDigit()
                    }
                    Button {
                        completeTap(i: i, set: set, resolved: r)
                    } label: {
                        Text("✓ Complete")
                            .font(DT.Type.body.weight(.bold))
                            .foregroundStyle(DT.Colors.onSignal)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(DT.Colors.signal)
                            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))
                    }
                }
            }
            .padding(.horizontal, DT.Spacing.s16 + 2)
            .padding(.vertical, DT.Spacing.s12)
            .overlay(alignment: .bottom) { DT.Colors.hairline.frame(height: 1) }
        }
    }

    private func stackedField(i: Int, field: FieldSelection.Field, label: String, text: String, ghost: Bool) -> some View {
        Button { selection = .init(row: i, field: field) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(DT.Type.eyebrow).foregroundStyle(DT.Colors.textTertiary)
                Text(text)
                    .font(DT.Type.numericLarge)
                    .foregroundStyle(ghost ? DT.Colors.textTertiary : DT.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, DT.Spacing.s8)
            .background(DT.Colors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.input))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.input).strokeBorder(DT.Colors.hairline))
        }
        .buttonStyle(.plain)
    }

    // MARK: shared pieces

    private func typeBadge(set: SetEntry, showRestSuffix: Bool) -> some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { t in
                Button(t.rawValue.capitalized) { set.type = t; vm.store.touch() }
            }
        } label: {
            HStack(spacing: 4) {
                Text(badgeLabel(set))
                    .font(DT.Type.secondary.weight(.bold))
                    .foregroundStyle(set.type == .warmup ? DT.Colors.pr : DT.Colors.textSecondary)
                if showRestSuffix {
                    Text(restText(seconds: restSeconds))
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.textTertiary)
                }
            }
        }
    }

    private func badgeLabel(_ set: SetEntry) -> String {
        let sets = vm.orderedSets(exercise).filter { $0.type == set.type }
        let n = (sets.firstIndex { $0.id == set.id } ?? 0) + 1
        switch set.type {
        case .working: return "\(n)"
        case .warmup: return "W\(sub(n))"
        case .drop: return "D\(sub(n))"
        case .failure: return "F\(sub(n))"
        case .bodyweight: return "B\(sub(n))"
        }
    }

    private func sub(_ n: Int) -> String {
        let subs = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
        return String(n).compactMap { $0.wholeNumberValue.map { subs[$0] } }.joined()
    }

    private func fieldButton(i: Int, field: FieldSelection.Field, width: CGFloat,
                             text: String, ghost: Bool, done: Bool) -> some View {
        Button {
            guard !done else { return }
            selection = selection == .init(row: i, field: field) ? nil : .init(row: i, field: field)
        } label: {
            Text(text)
                .font(DT.Type.numericRow)
                .foregroundStyle(ghost && !done ? DT.Colors.textTertiary : DT.Colors.textPrimary)
                .frame(width: width, height: 30)
                .background(DT.Colors.surfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.input))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.input)
                    .strokeBorder(selection == .init(row: i, field: field) ? DT.Colors.signal : DT.Colors.hairline))
        }
        .buttonStyle(.plain)
    }

    private func completeControl(i: Int, set: SetEntry, resolved: GhostResolver.Resolved) -> some View {
        let done = set.completedAt != nil
        return Button {
            completeTap(i: i, set: set, resolved: resolved)
        } label: {
            Text(done ? "✓" : "○")
                .font(DT.Type.body.weight(.bold))
                .foregroundStyle(done ? DT.Colors.onSignal : DT.Colors.textTertiary)
                .frame(width: 26, height: 26)
                .background(done ? DT.Colors.signal : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.checkbox))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.checkbox)
                    .strokeBorder(done ? DT.Colors.signal : DT.Colors.hairline, lineWidth: 1.5))
                .scaleEffect(done ? 1.0 : 0.95)
        }
        .buttonStyle(.plain)
        .frame(width: DT.Touch.setCompleteWidth, height: DT.Touch.setCompleteHeight)
        .contentShape(Rectangle())
    }

    private func completeTap(i: Int, set: SetEntry, resolved: GhostResolver.Resolved) {
        // Optimistic: state mutates immediately (<50ms visual), persistence is
        // debounced in the store.
        let outcome: WorkoutViewModel.CompletionOutcome
        if reduceMotion {
            outcome = vm.complete(exercise: exercise, rowIndex: i,
                                  resolved: resolved, restSeconds: restSeconds,
                                  bestWeight: nil, bestReps: nil,
                                  startRest: startsRestOnComplete)
        } else {
            withAnimation(DT.Motion.setComplete) {
                // animation wraps the state change; assignment below is outside
            }
            outcome = vm.complete(exercise: exercise, rowIndex: i,
                                  resolved: resolved, restSeconds: restSeconds,
                                  bestWeight: nil, bestReps: nil,
                                  startRest: startsRestOnComplete)
        }
        selection = nil
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        if outcome.isPR {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if set.completedAt != nil { onSetCompleted() }
    }

    private func weightText(_ w: Decimal?) -> String {
        guard let w else { return "—" }
        return NSDecimalNumber(decimal: w).doubleValue
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    private func rpeText(_ r: Double?) -> String {
        guard let r else { return "—" }
        return r.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func restText(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Inline ± stepper accessory (§3 contract #2). Increment: 2.5 kg weight,
/// 1 rep, 0.5 RPE, 15 s rest (plate step from Settings in Phase 8).
struct StepperAccessory: View {
    @Bindable var vm: WorkoutViewModel
    let exercise: SessionExercise
    let selection: SetTableView.FieldSelection
    var onClose: () -> Void

    var body: some View {
        let sets = vm.orderedSets(exercise)
        if sets.indices.contains(selection.row) {
            let set = sets[selection.row]
            HStack {
                Text("\(selection.field.rawValue.uppercased()) · SET \(set.index + 1)")
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(DT.Colors.textTertiary)
                Spacer()
                Button("−") { step(set, -1) }.buttonStyle(StepChip(on: false))
                Text(current(set))
                    .font(DT.Type.numericLarge)
                    .frame(minWidth: 52)
                Button("+") { step(set, 1) }.buttonStyle(StepChip(on: true))
                Button("✕", action: onClose)
                    .foregroundStyle(DT.Colors.textTertiary)
                    .frame(width: DT.Touch.minimum, height: DT.Touch.minimum)
            }
            .padding(.horizontal, DT.Spacing.s12 + 2)
            .padding(.vertical, DT.Spacing.s8 + 2)
            .background(DT.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card + 6))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.card + 6).strokeBorder(DT.Colors.hairline))
            .shadow(color: DT.Elevation.raisedShadowColor, radius: DT.Elevation.raisedShadowRadius,
                    y: DT.Elevation.raisedShadowY)
            .padding(.horizontal, DT.Spacing.s12 + 2)
        }
    }

    private func step(_ set: SetEntry, _ d: Double) {
        switch selection.field {
        case .weight:
            let cur = set.weightKg ?? 0
            set.weightKg = max(0, cur + Decimal(d) * Decimal(2.5))
        case .reps:
            set.reps = max(0, (set.reps ?? 0) + Int(d))
        case .rpe:
            set.rpe = min(10, max(5, (set.rpe ?? 7.5) + d * 0.5))
        case .rest:
            break // per-set rest lands with RoutineItem wiring (Phase 7)
        }
        vm.markTouched(exercise: exercise, row: selection.row)
    }

    private func current(_ set: SetEntry) -> String {
        switch selection.field {
        case .weight:
            guard let w = set.weightKg else { return "—" }
            return NSDecimalNumber(decimal: w).doubleValue.formatted(.number.precision(.fractionLength(0...1)))
        case .reps: return set.reps.map(String.init) ?? "—"
        case .rpe: return set.rpe?.formatted(.number.precision(.fractionLength(0...1))) ?? "—"
        case .rest:
            let r = vm.restSeconds(for: exercise)
            return String(format: "%d:%02d", r / 60, r % 60)
        }
    }

    struct StepChip: ButtonStyle {
        var on: Bool
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(DT.Type.body)
                .foregroundStyle(on ? DT.Colors.signal : DT.Colors.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(on ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(on ? DT.Colors.signal : DT.Colors.hairline))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}
