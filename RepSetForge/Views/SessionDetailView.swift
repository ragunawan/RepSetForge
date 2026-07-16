import SwiftUI
import SwiftData

/// Editable view of a *completed* session, reached from `HistoryView`'s list
/// rows — this is what makes the historical edit invalidation chain (dev
/// spec §5) reachable at all; there was previously no way to edit a past
/// session's sets. Deliberately simpler than `SetRowView`/`ExerciseFocusView`
/// (no ghost values, no rest timer, no completion state — every set here is
/// already completed by definition) rather than adding an edit-mode branch
/// to the already-hardened live-logging component.
///
/// Recompute is triggered on `.onSubmit` for weight/reps fields (a
/// deliberate simplification — the underlying value is always saved
/// immediately via the direct SwiftData binding either way, so the only
/// thing deferred to submit is the derived-data recompute, avoiding running
/// the full invalidation chain on every keystroke) and unconditionally on
/// swipe-to-delete.
struct SessionDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Query private var allSetEntries: [SetEntry]
    @Query private var allPRRecords: [PRRecord]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]

    @State private var isRecalculating = false

    private var sessionExercises: [SessionExercise] {
        session.sessionExercises.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            ForEach(sessionExercises) { sessionExercise in
                Section(sessionExercise.exercise?.name ?? "Exercise") {
                    ForEach(sessionExercise.setEntries.sorted { $0.index < $1.index }) { set in
                        setRow(set, sessionExercise: sessionExercise)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: sessionExercise)
                    }
                }
                .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RepSetForgeTheme.Colors.surface)
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isRecalculating {
                Text("Recalculating records…")
                    .font(RepSetForgeTheme.Typography.mono(12, weight: .semibold))
                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RepSetForgeTheme.Colors.surfaceRaised, in: Capsule())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 6)
            }
        }
    }

    private func setRow(_ set: SetEntry, sessionExercise: SessionExercise) -> some View {
        HStack(spacing: 8) {
            Text(set.type.badgeLetter.map { $0 + String(set.index + 1) } ?? String(set.index + 1))
                .font(RepSetForgeTheme.Typography.mono(11, weight: .bold))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                .frame(width: 26)

            weightField(set, sessionExercise: sessionExercise)
            repsField(set, sessionExercise: sessionExercise)

            if set.isPR {
                Text("PR")
                    .font(RepSetForgeTheme.Typography.mono(9, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RepSetForgeTheme.Colors.prDim, in: Capsule())
                    .foregroundStyle(RepSetForgeTheme.Colors.pr)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func weightField(_ set: SetEntry, sessionExercise: SessionExercise) -> some View {
        TextField(
            "Weight",
            text: Binding(
                get: { set.weightKg.map(Self.formatDecimal) ?? "" },
                set: { set.weightKg = Decimal(string: $0.replacingOccurrences(of: ",", with: ".")) }
            )
        )
        .keyboardType(.decimalPad)
        .font(RepSetForgeTheme.Typography.mono(13))
        .frame(width: 58)
        .padding(6)
        .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
        .onSubmit { invalidate(sessionExercise) }
    }

    private func repsField(_ set: SetEntry, sessionExercise: SessionExercise) -> some View {
        TextField(
            "Reps",
            text: Binding(
                get: { set.reps.map(String.init) ?? "" },
                set: { set.reps = Int($0) }
            )
        )
        .keyboardType(.numberPad)
        .font(RepSetForgeTheme.Typography.mono(13))
        .frame(width: 40)
        .padding(6)
        .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: RepSetForgeTheme.Radius.input))
        .onSubmit { invalidate(sessionExercise) }
    }

    private func delete(_ offsets: IndexSet, from sessionExercise: SessionExercise) {
        let sorted = sessionExercise.setEntries.sorted { $0.index < $1.index }
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        invalidate(sessionExercise)
    }

    private func invalidate(_ sessionExercise: SessionExercise) {
        guard let exercise = sessionExercise.exercise else { return }
        Task {
            let toastTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled { isRecalculating = true }
            }
            await HistoricalEditInvalidationService.run(
                session: session,
                touchedExercises: [exercise],
                allSetEntries: allSetEntries,
                allPRRecords: allPRRecords,
                bodyweightKg: bodyMetrics.first?.bodyweightKg,
                context: modelContext
            )
            toastTask.cancel()
            isRecalculating = false
        }
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
