import SwiftUI
import SwiftData

/// §5 History: session list grouped by month; historical edit/delete runs
/// the §6 invalidation chain.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var editing: WorkoutSession?
    private let health = HealthKitExporter()

    private var completed: [WorkoutSession] { sessions.filter { $0.status == .completed } }

    var body: some View {
        NavigationStack {
            Group {
                if completed.isEmpty {
                    VStack(spacing: DT.Spacing.s8) {
                        Text("NO WORKOUTS YET")
                            .font(DT.Type.eyebrow)
                            .foregroundStyle(DT.Colors.textTertiary)
                        Text("Finished sessions appear here")
                            .font(DT.Type.secondary)
                            .foregroundStyle(DT.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(monthKeys, id: \.self) { month in
                            Section(month) {
                                ForEach(byMonth[month] ?? [], id: \.persistentModelID) { session in
                                    row(session)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DT.Colors.surface)
            .navigationTitle("History")
            .sheet(item: $editing) { SessionDetailView(session: $0) }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    private var byMonth: [String: [WorkoutSession]] {
        Dictionary(grouping: completed) {
            $0.startedAt.formatted(.dateTime.month(.wide).year())
        }
    }

    private var monthKeys: [String] {
        var seen = Set<String>()
        return completed.compactMap {
            let k = $0.startedAt.formatted(.dateTime.month(.wide).year())
            return seen.insert(k).inserted ? k : nil
        }
    }

    private func row(_ session: WorkoutSession) -> some View {
        let sets = (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter { $0.completedAt != nil }
        let prCount = sets.filter(\.isPR).count
        return Button { editing = session } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name).font(DT.Type.body.weight(.bold))
                    HStack(spacing: 4) {
                        Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        Text("· \(sets.count) sets")
                        if prCount > 0 {
                            Text("· \(prCount) PR").foregroundStyle(DT.Colors.pr)
                        }
                    }
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
                    .monospacedDigit()
                }
                Spacer()
                Text("›").foregroundStyle(DT.Colors.textTertiary)
            }
        }
        .listRowBackground(DT.Colors.surface)
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await InvalidationChain.deleteSession(session, context: context, health: health) }
            }
        }
    }
}

/// Read/edit view for a past session. Any mutation runs the invalidation
/// chain on dismiss (§6: PRs, ladder, rollups, Health re-write).
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    @State private var edited = false
    private let health = HealthKitExporter()

    var body: some View {
        NavigationStack {
            List {
                ForEach((session.exercises ?? []).sorted { $0.order < $1.order },
                        id: \.persistentModelID) { ex in
                    Section(ex.exercise?.name ?? "Exercise") {
                        ForEach((ex.sets ?? []).sorted { $0.index < $1.index },
                                id: \.persistentModelID) { set in
                            setRow(set)
                        }
                        .onDelete { idx in
                            let sorted = (ex.sets ?? []).sorted { $0.index < $1.index }
                            for i in idx { context.delete(sorted[i]) }
                            edited = true
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    if edited {
                        let touched = (session.exercises ?? []).compactMap(\.exercise)
                        Task {
                            await InvalidationChain.run(touchedExercises: touched,
                                                        editedSession: session,
                                                        context: context, health: health)
                        }
                    }
                    dismiss()
                }
            }
        }
        .font(DT.Type.body)
    }

    private func setRow(_ set: SetEntry) -> some View {
        HStack {
            Text(set.type.rawValue.prefix(1).uppercased())
                .font(DT.Type.eyebrow)
                .foregroundStyle(set.type == .warmup ? DT.Colors.pr : DT.Colors.textTertiary)
                .frame(width: 20)
            let w = set.weightKg.map { NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...1))) } ?? "—"
            Text("\(w) kg × \(set.reps.map(String.init) ?? "—")")
                .font(DT.Type.numericRow)
                .monospacedDigit()
            if let rpe = set.rpe {
                Text("@ \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(DT.Type.secondary)
                    .foregroundStyle(DT.Colors.textSecondary)
            }
            Spacer()
            if set.isPR {
                Text("PR").font(DT.Type.eyebrow.weight(.heavy)).foregroundStyle(DT.Colors.pr)
            }
        }
        .listRowBackground(DT.Colors.surface)
    }
}
