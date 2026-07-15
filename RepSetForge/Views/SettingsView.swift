import SwiftUI
import SwiftData

/// dev spec §6, mockup frame 10, opened from Home's profile button (§1).
/// CSV import/export and the plate-calculator config aren't built — there's
/// no plate-calculator UI to configure yet, and CSV I/O is its own chunk of
/// work (TODO.md). Units is stored but not yet threaded through every kg
/// display in the app. Default rest duration and RPE visibility *are*
/// wired into `ExerciseFocusView`/`SetRowView`; theme is wired at the app root.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingsKeys.weightUnit) private var weightUnit: WeightUnitPreference = .kilograms
    @AppStorage(AppSettingsKeys.defaultRestSeconds) private var defaultRestSeconds = 90
    @AppStorage(AppSettingsKeys.showRPE) private var showRPE = true
    @AppStorage(AppSettingsKeys.theme) private var theme: ThemePreference = .system

    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyMetrics: [BodyMetric]
    @State private var isPresentingLogWeight = false
    @State private var isPresentingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Training") {
                    Picker("Units", selection: $weightUnit) {
                        ForEach(WeightUnitPreference.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    Stepper(
                        "Default rest: \(Self.formatDuration(defaultRestSeconds))",
                        value: $defaultRestSeconds,
                        in: 30...300,
                        step: 15
                    )
                    Toggle("Show RPE", isOn: $showRPE)
                    if let bodyweight = bodyMetrics.first?.bodyweightKg {
                        HStack {
                            Text("Bodyweight")
                            Spacer()
                            Text("\(Self.formatDecimal(bodyweight)) kg")
                                .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                        }
                    }
                    Button("Log weight") { isPresentingLogWeight = true }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(ThemePreference.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Data") {
                    HStack {
                        Text("iCloud sync")
                        Spacer()
                        Text(iCloudStatusText)
                            .foregroundStyle(RepSetForgeTheme.Colors.textSecondary)
                    }
                }

                Section {
                    Button("Delete all data", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isPresentingLogWeight) {
            LogBodyMetricSheet()
        }
        .alert("Delete all data?", isPresented: $isPresentingDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) { deleteConfirmationText = "" }
            Button("Delete Everything", role: .destructive) {
                if deleteConfirmationText == "DELETE" {
                    deleteAllData()
                }
                deleteConfirmationText = ""
            }
        } message: {
            Text("This permanently deletes every workout, routine, and exercise. This can't be undone. Type DELETE to confirm.")
        }
    }

    /// Best-effort — not a real CloudKit account/container status check
    /// (that's async and needs a CKContainer round-trip); just whether an
    /// iCloud account is signed in at all on this device.
    private var iCloudStatusText: String {
        FileManager.default.ubiquityIdentityToken != nil ? "Available" : "Not signed in"
    }

    private func deleteAllData() {
        // Order doesn't matter for correctness — every relationship here is
        // optional, so nothing requires a specific delete sequence.
        try? modelContext.delete(model: WorkoutSession.self)
        try? modelContext.delete(model: Routine.self)
        try? modelContext.delete(model: Exercise.self)
        try? modelContext.delete(model: BodyMetric.self)
        try? modelContext.delete(model: PRRecord.self)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
