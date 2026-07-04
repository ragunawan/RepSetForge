import SwiftUI

/// Fast set logging for one skill: tap a set to toggle it complete, with a
/// simple rest countdown afterward — the two things worth doing from the
/// wrist mid-workout. Reps/weight themselves stay phone-only to edit; this
/// view only toggles completion of whatever was already planned there.
struct WatchExerciseView: View {
    @Bindable var exercise: Exercise
    @State private var restSecondsRemaining: Int?

    private var sortedSets: [ExerciseSet] {
        exercise.sets.sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        List {
            if let restSecondsRemaining {
                Label("Resting: \(restSecondsRemaining)s", systemImage: "hourglass")
                    .foregroundStyle(Color.questGold)
            }
            ForEach(sortedSets) { set in
                Button {
                    set.completed.toggle()
                    if set.completed {
                        restSecondsRemaining = exercise.defaultRestSeconds > 0 ? exercise.defaultRestSeconds : nil
                    }
                } label: {
                    HStack {
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(set.completed ? Color.questGreen : Color.secondary)
                        Text("Set \(set.setNumber): \(set.reps) × \(set.weightUnit.formatted(set.weight))")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(set.setNumber)")
                .accessibilityValue(set.completed ? "Complete" : "Not complete")
            }
        }
        .navigationTitle(exercise.name)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let remaining = restSecondsRemaining else { return }
            restSecondsRemaining = remaining > 1 ? remaining - 1 : nil
        }
    }
}

#Preview {
    NavigationStack {
        WatchExerciseView(exercise: Fixtures.makeExercise(sets: [(8, 135, false), (8, 135, true)]))
    }
}
