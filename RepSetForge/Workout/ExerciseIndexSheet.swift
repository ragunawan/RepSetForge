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

/// §3 Progression panel shell (PROG · CHART · LOG · NOTES tabs). The rule
/// editor + ladder engine land in Phase 4; this presents the structure.
struct ProgressionPanel: View {
    @Bindable var vm: WorkoutViewModel
    @State private var tab = "PROG"

    var body: some View {
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
            Spacer()
            Text("PROGRESSION RULE · DOUBLE PROGRESSION")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.textTertiary)
                .frame(maxWidth: .infinity)
            Text("Ladder engine lands in Phase 4")
                .font(DT.Type.secondary)
                .foregroundStyle(DT.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, DT.Spacing.s4)
            Spacer()
        }
        .background(DT.Colors.surface)
        .presentationDetents([.large])
        .presentationCornerRadius(DT.Radius.phoneSheet)
    }
}
