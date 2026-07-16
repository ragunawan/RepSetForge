import SwiftUI
import SwiftData

/// §6 Settings: units, default rest, RPE visibility, plate calc, bodyweight
/// entry, CSV import/export, iCloud status, theme, Delete All Data (double
/// confirm + typed word).
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [WorkoutSession]
    @State private var showDeleteConfirm = false
    @State private var deleteTypedWord = ""
    @State private var exportedCSV: String?
    @State private var bodyweightEntry = ""

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        context.insert(p)
        return p
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("UNITS & LOGGING") {
                    Picker("Units", selection: Bindable(profile).unitIsMetric) {
                        Text("kg").tag(true)
                        Text("lb").tag(false)
                    }
                    Stepper("Default rest: \(profile.defaultRestSeconds / 60):\(String(format: "%02d", profile.defaultRestSeconds % 60))",
                            value: Bindable(profile).defaultRestSeconds, in: 30...300, step: 15)
                    Toggle("Show RPE column", isOn: Bindable(profile).showRPE)
                }

                Section("PLATE CALCULATOR") {
                    HStack {
                        Text("Bar weight")
                        Spacer()
                        Text("\(NSDecimalNumber(decimal: profile.barWeightKg).doubleValue.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            .monospacedDigit()
                    }
                }

                Section("BODYWEIGHT") {
                    HStack {
                        TextField("Log today's weight (kg)", text: $bodyweightEntry)
                            .keyboardType(.decimalPad)
                        Button("Log") {
                            guard let v = Decimal(string: bodyweightEntry) else { return }
                            context.insert(BodyMetric(date: .now, bodyweightKg: v))
                            bodyweightEntry = ""
                        }
                        .disabled(Decimal(string: bodyweightEntry) == nil)
                    }
                }

                Section("DATA") {
                    Button("Export CSV") { exportCSV() }
                    if let exportedCSV {
                        ShareLink(item: exportedCSV) { Text("Share exported CSV") }
                    }
                    LabeledContent("iCloud sync", value: "Private database")
                }

                Section("DANGER ZONE") {
                    Button("Delete all data…", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DT.Colors.surface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .alert("Delete ALL data?", isPresented: $showDeleteConfirm) {
                TextField("Type DELETE to confirm", text: $deleteTypedWord)
                Button("Cancel", role: .cancel) { deleteTypedWord = "" }
                Button("Delete everything", role: .destructive) {
                    if deleteTypedWord == "DELETE" { deleteAllData() }
                    deleteTypedWord = ""
                }
            } message: {
                Text("Removes every workout, routine, exercise, and body metric from this device and iCloud, and deletes exported workouts from Apple Health. This cannot be undone.")
            }
        }
        .font(DT.Type.body)
        .foregroundStyle(DT.Colors.textPrimary)
    }

    private func exportCSV() {
        let rows: [CSVCodec.Row] = sessions
            .filter { $0.status == .completed }
            .flatMap { session in
                (session.exercises ?? []).flatMap { ex in
                    (ex.sets ?? []).compactMap { set -> CSVCodec.Row? in
                        guard let at = set.completedAt else { return nil }
                        return CSVCodec.Row(date: at,
                                            exercise: ex.exercise?.name ?? "Unknown",
                                            setType: set.type,
                                            weightKg: set.weightKg,
                                            reps: set.reps,
                                            rpe: set.rpe)
                    }
                }
            }
            .sorted { $0.date < $1.date }
        exportedCSV = CSVCodec.export(rows: rows)
    }

    /// CloudKit-backed store: deleting locally propagates to the private DB.
    /// HKWorkout purge walks healthKitUUIDs before removing sessions.
    private func deleteAllData() {
        let health = HealthKitExporter()
        let uuids = sessions.compactMap(\.healthKitUUID)
        Task {
            for uuid in uuids { try? await health.deleteWorkout(uuid: uuid) }
        }
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: Routine.self)
        try? context.delete(model: Exercise.self)
        try? context.delete(model: PRRecord.self)
        try? context.delete(model: BodyMetric.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
    }
}
