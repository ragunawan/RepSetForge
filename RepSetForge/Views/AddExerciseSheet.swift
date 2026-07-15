import SwiftUI
import SwiftData

/// Minimal stand-in for the full Exercise Selection screen (dev spec mockup
/// frame 3, TODO.md build-order step 4) — enough to add an exercise to a
/// session and exercise the dedup flow. No search debounce, recents,
/// favorites, or muscle/equipment chip filters yet.
struct AddExerciseSheet: View {
    let onAdd: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var name = ""
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var equipment: Equipment = .barbell

    private var similarMatches: [ExerciseDedupService.Match] {
        ExerciseDedupService.similarExercises(to: name, in: allExercises)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Existing exercises") {
                    if allExercises.isEmpty {
                        Text("No exercises yet — create your first one below.")
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    }
                    ForEach(allExercises) { exercise in
                        Button {
                            onAdd(exercise)
                            dismiss()
                        } label: {
                            Text(exercise.name)
                        }
                    }
                }

                Section("Create new") {
                    TextField("Name", text: $name)

                    if !similarMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Similar exists")
                                .font(.caption.bold())
                                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                            ForEach(similarMatches, id: \.exercise.id) { match in
                                Button {
                                    onAdd(match.exercise)
                                    dismiss()
                                } label: {
                                    Text(match.exercise.name)
                                }
                            }
                        }
                    }

                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    muscleGroupPicker

                    Button("Create \"\(name)\"") {
                        createExercise()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var muscleGroupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(MuscleGroup.allCases) { group in
                    let isSelected = selectedMuscles.contains(group)
                    Button {
                        if isSelected { selectedMuscles.remove(group) } else { selectedMuscles.insert(group) }
                    } label: {
                        Text(group.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                isSelected ? RepSetForgeTheme.Colors.signalDim : RepSetForgeTheme.Colors.surfaceInput,
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? RepSetForgeTheme.Colors.signal : RepSetForgeTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func createExercise() {
        let exercise = Exercise(
            name: name,
            muscleGroups: Array(selectedMuscles),
            equipment: equipment
        )
        modelContext.insert(exercise)
        onAdd(exercise)
        dismiss()
    }
}
