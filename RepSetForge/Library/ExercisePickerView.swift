import SwiftUI
import SwiftData

/// §5 exercise picker: search, recents, favorites, muscle filter. The DB
/// ships empty — first run shows "Create your first exercise".
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var showCreate = false
    var onPick: (Exercise) -> Void = { _ in }

    enum Filter: String, CaseIterable {
        case all = "ALL", favorites = "FAV", recents = "RECENT"
    }

    private var filtered: [Exercise] {
        var list = exercises
        switch filter {
        case .favorites: list = list.filter(\.isFavorite)
        case .recents: list = list.sorted { $0.createdAt > $1.createdAt }
        case .all: break
        }
        guard !search.isEmpty else { return list }
        let key = StrengthMath.canonicalNameKey(search)
        return list.filter { $0.canonicalNameKey.contains(key) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    firstRunState
                } else {
                    list
                }
            }
            .background(DT.Colors.surface)
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showCreate) {
                CreateExerciseView { created in
                    onPick(created)
                    dismiss()
                }
            }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    private var firstRunState: some View {
        VStack(spacing: DT.Spacing.s12) {
            Text("NO EXERCISES YET")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.textTertiary)
            Text("Create your first exercise")
                .font(DT.Type.heading)
            Button {
                showCreate = true
            } label: {
                Text("+ Create exercise")
                    .font(DT.Type.body.weight(.bold))
                    .foregroundStyle(DT.Colors.onSignal)
                    .padding(.horizontal, DT.Spacing.s24)
                    .frame(minHeight: DT.Touch.minimum)
                    .background(DT.Colors.signal)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: DT.Spacing.s8 - 2) {
                ForEach(Filter.allCases, id: \.self) { f in
                    Button(f.rawValue) { filter = f }
                        .font(DT.Type.eyebrow)
                        .foregroundStyle(filter == f ? DT.Colors.signal : DT.Colors.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(filter == f ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(filter == f ? DT.Colors.signal : DT.Colors.hairline))
                }
                Spacer()
            }
            .padding(.horizontal, DT.Spacing.s16)
            .padding(.vertical, DT.Spacing.s8)

            List(filtered) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).font(DT.Type.body.weight(.bold))
                            Text(exercise.muscleGroups.joined(separator: " · "))
                                .font(DT.Type.secondary)
                                .foregroundStyle(DT.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            exercise.isFavorite.toggle()
                        } label: {
                            Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(exercise.isFavorite ? DT.Colors.pr : DT.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(DT.Colors.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $search)
        }
    }
}

/// §5 create flow: name + muscles + equipment, with the §2 dedup guard —
/// fuzzy "Similar exists" rows shown before allowing create.
struct CreateExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [Exercise]
    @State private var name = ""
    @State private var muscles = ""
    @State private var equipment = ""
    var onCreate: (Exercise) -> Void = { _ in }

    private var similar: [Exercise] {
        guard name.count >= 3 else { return [] }
        let keys = ExerciseDeduplicator.similarKeys(to: name, existingKeys: existing.map(\.canonicalNameKey))
        return existing.filter { keys.contains($0.canonicalNameKey) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Muscles (comma-separated)", text: $muscles)
                    TextField("Equipment", text: $equipment)
                }
                if !similar.isEmpty {
                    Section("SIMILAR EXISTS") {
                        ForEach(similar) { ex in
                            Button {
                                onCreate(ex)  // reuse instead of duplicating
                                dismiss()
                            } label: {
                                HStack {
                                    Text(ex.name)
                                    Spacer()
                                    Text("Use this").foregroundStyle(DT.Colors.signal)
                                }
                                .font(DT.Type.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let ex = Exercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            muscleGroups: muscles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            equipment: equipment.trimmingCharacters(in: .whitespaces),
                            isCustom: true)
                        context.insert(ex)
                        onCreate(ex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .font(DT.Type.body)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(DT.Radius.phoneSheet)
    }
}
