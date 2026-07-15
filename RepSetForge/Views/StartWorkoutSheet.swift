import SwiftUI
import SwiftData

/// Minimal stand-in for the mockup's start-workout flow — routine-driven
/// starts (Recommended next, routine library) are TODO.md build-order step
/// 6; this is quick-start only: name it, start logging.
struct StartWorkoutSheet: View {
    let onStart: (WorkoutSession) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Workout"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Workout name", text: $name)
            }
            .navigationTitle("Start workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func start() {
        let session = WorkoutSession(name: name)
        modelContext.insert(session)
        onStart(session)
        dismiss()
    }
}
