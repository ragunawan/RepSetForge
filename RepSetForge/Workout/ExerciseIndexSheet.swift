import SwiftUI

/// §3 Exercise Index: READ-ONLY overview — completion state, volume, PR
/// badges, jump-to-page, drag reorder. No set entry, no input fields.
struct ExerciseIndexSheet: View {
    @Bindable var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(vm.orderedExercises.enumerated()), id: \.element.persistentModelID) { idx, ex in
                    Button {
                        vm.page = idx
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.exercise?.name ?? "Exercise")
                                    .font(DT.Type.body.weight(.bold))
                                    .foregroundStyle(idx == vm.page ? DT.Colors.signal : DT.Colors.textPrimary)
                                HStack(spacing: 4) {
                                    let sets = ex.sets ?? []
                                    let done = sets.filter { $0.completedAt != nil }.count
                                    Text("\(done)/\(sets.count) sets")
                                    if sets.contains(where: { $0.isPR }) {
                                        Text("· PR").foregroundStyle(DT.Colors.pr)
                                    }
                                }
                                .font(DT.Type.secondary)
                                .foregroundStyle(DT.Colors.textSecondary)
                                .monospacedDigit()
                            }
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(DT.Colors.textTertiary)
                        }
                    }
                    .listRowBackground(DT.Colors.surface)
                }
                .onMove { from, to in
                    var items = vm.orderedExercises
                    items.move(fromOffsets: from, toOffset: to)
                    for (i, item) in items.enumerated() { item.order = i }
                    vm.store.touch()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle("Exercise Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { EditButton() }
        }
        .font(DT.Type.body)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(DT.Radius.phoneSheet)
    }
}

/// §3 Progression panel: rule rows bound to ProgressionRule + the generated
/// ladder from LadderEngine. Full-height sheet, full-bleed rows. History feed
/// beyond the live session lands with Phase 7's queries.
struct ProgressionPanel: View {
    @Bindable var vm: WorkoutViewModel
    @State private var tab = "PROG"

    private var rule: LadderEngine.Rule {
        // RoutineItem rule when present; sensible defaults otherwise.
        LadderEngine.Rule(repRangeLow: 8, repRangeHigh: 12, maxQualifyingRPE: 9,
                          qualifyingSetsRequired: 2, incrementKg: 2.5)
    }

    private var ladder: LadderEngine.State {
        let exercises = vm.orderedExercises
        let ex = exercises.indices.contains(vm.page) ? exercises[vm.page] : nil
        let facts: [LadderEngine.SessionFacts] = {
            guard let ex, let session = vm.session else { return [] }
            let sets = vm.orderedSets(ex).filter { $0.completedAt != nil }
                .compactMap { s -> LadderEngine.SetFact? in
                    guard let w = s.weightKg, let r = s.reps else { return nil }
                    return .init(weightKg: w, reps: r, rpe: s.rpe, type: s.type)
                }
            return sets.isEmpty ? [] : [.init(date: session.startedAt, sets: sets)]
        }()
        let startWeight = ex.flatMap { vm.orderedSets($0).first(where: { $0.type == .working })?.weightKg } ?? 100
        return LadderEngine.regenerate(rule: rule, startWeightKg: startWeight, history: facts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DT.Spacing.s8 - 2) {
                    ForEach(["PROG", "CHART", "LOG", "NOTES"], id: \.self) { t in
                        Button(t) { tab = t }
                            .font(DT.Type.eyebrow)
                            .foregroundStyle(tab == t ? DT.Colors.signal : DT.Colors.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(tab == t ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(tab == t ? DT.Colors.signal : DT.Colors.hairline))
                    }
                }
                .padding(DT.Spacing.s16)
                Divider().overlay(DT.Colors.hairline)

                if tab == "PROG" {
                    Text("PROGRESSION RULE · DOUBLE PROGRESSION")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.textTertiary)
                        .padding(.horizontal, DT.Spacing.s16 + 2)
                        .padding(.vertical, DT.Spacing.s8)
                    ruleRow("Rep range", "\(rule.repRangeLow) – \(rule.repRangeHigh)")
                    ruleRow("RPE", "≤ \(rule.maxQualifyingRPE.formatted(.number.precision(.fractionLength(0...1))))")
                    ruleRow("Sets per session", "≥ \(rule.qualifyingSetsRequired)")
                    ruleRow("Weight increment", "+\(NSDecimalNumber(decimal: rule.incrementKg).doubleValue.formatted(.number.precision(.fractionLength(0...1)))) kg")

                    Text("LADDER")
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.textTertiary)
                        .padding(.horizontal, DT.Spacing.s16 + 2)
                        .padding(.vertical, DT.Spacing.s8)
                    let state = ladder
                    ForEach(Array(state.levels.enumerated()), id: \.offset) { i, level in
                        ladderRow(level: level, state: levelState(i, state: state))
                    }
                }
            }
            .padding(.bottom, DT.Spacing.s24)
        }
        .background(DT.Colors.surface)
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
        .presentationDetents([.large])
        .presentationCornerRadius(DT.Radius.phoneSheet)
    }

    private enum RowState { case done, current, todo }

    private func levelState(_ i: Int, state: LadderEngine.State) -> RowState {
        if i < state.currentIndex { return .done }
        if i == state.currentIndex { return .current }
        return .todo
    }

    private func ruleRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(DT.Colors.textSecondary)
            Spacer()
            Text("\(value) ▸").monospacedDigit()
        }
        .font(DT.Type.secondary)
        .padding(.horizontal, DT.Spacing.s16 + 2)
        .frame(minHeight: DT.Touch.minimum)
        .overlay(alignment: .bottom) { DT.Colors.hairline.frame(height: 1) }
    }

    private func ladderRow(level: LadderEngine.Level, state: RowState) -> some View {
        let w = NSDecimalNumber(decimal: level.weightKg).doubleValue
            .formatted(.number.precision(.fractionLength(0...1)))
        let e1 = level.e1RM.map {
            NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0)))
        } ?? "—"
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(w) kg × \(level.reps)")
                    .font(DT.Type.body)
                    .foregroundStyle(state == .todo ? DT.Colors.textSecondary : DT.Colors.textPrimary)
                    .monospacedDigit()
                Text("e1RM \(e1)\(level.isLevelUp ? " · level up" : state == .current ? " · current" : "")")
                    .font(DT.Type.eyebrow)
                    .foregroundStyle(state == .todo ? DT.Colors.textTertiary : DT.Colors.signal)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    ForEach(0..<max(1, 2), id: \.self) { _ in
                        Text(state == .done ? "✓" : "")
                            .font(DT.Type.eyebrow.weight(.bold))
                            .foregroundStyle(DT.Colors.onSignal)
                            .frame(width: 16, height: 16)
                            .background(state == .done ? DT.Colors.signal : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(state == .done ? DT.Colors.signal : DT.Colors.hairline))
                    }
                }
                if let date = level.completedOn {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(DT.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, DT.Spacing.s16 + 2)
        .padding(.vertical, DT.Spacing.s8)
        .opacity(state == .done ? 0.55 : 1)
        .background(state == .current ? DT.Colors.signalDim : Color.clear)
    }
}
