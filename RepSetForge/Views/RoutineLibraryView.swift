import SwiftUI
import SwiftData

/// dev spec §5, mockup frame 5 — routines/exercises segmented list. The
/// "Exercises" tab reuses the same `Exercise` data `AddExerciseSheet`
/// creates; full search/filter chips are TODO.md build-order step 4 territory.
struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    private enum Segment: String, CaseIterable, Hashable {
        case routines = "Routines"
        case exercises = "Exercises"
    }

    @State private var segment: Segment = .routines
    @State private var isPresentingNewRoutine = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(12)

                switch segment {
                case .routines: routinesList
                case .exercises: exercisesList
                }
            }
            .background(RepSetForgeTheme.Colors.surface)
            .navigationTitle("Library")
            .toolbar {
                if segment == .routines {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPresentingNewRoutine = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingNewRoutine) {
            RoutineBuilderView(routine: nil)
        }
    }

    // MARK: - Routines

    private var routinesList: some View {
        Group {
            if routines.isEmpty {
                emptyRoutinesState
            } else {
                List {
                    ForEach(routines) { routine in
                        NavigationLink {
                            RoutineBuilderView(routine: routine)
                        } label: {
                            routineRow(routine)
                        }
                        .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(routines[index]) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
            Text(routineSummary(routine))
                .font(.system(size: 12))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func routineSummary(_ routine: Routine) -> String {
        var parts = ["\(routine.items.count) exercise\(routine.items.count == 1 ? "" : "s")"]
        if let lastPerformedAt = routine.lastPerformedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            parts.append("Last done \(formatter.localizedString(for: lastPerformedAt, relativeTo: .now))")
        }
        return parts.joined(separator: " · ")
    }

    private var emptyRoutinesState: some View {
        VStack(spacing: 10) {
            Text("Build a routine")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
            Text("Save a plan once, start it in one tap")
                .font(.system(size: 13))
                .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
            Button("+ New routine") { isPresentingNewRoutine = true }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(RepSetForgeTheme.Colors.surfaceInput, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Exercises

    private var exercisesList: some View {
        Group {
            if exercises.isEmpty {
                Text("No exercises yet")
                    .foregroundStyle(RepSetForgeTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(exercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RepSetForgeTheme.Colors.textPrimary)
                            if !exercise.muscleGroups.isEmpty {
                                Text(exercise.muscleGroups.map(\.displayName).joined(separator: " · "))
                                    .font(.system(size: 12))
                                    .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(RepSetForgeTheme.Colors.surfaceRaised)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
