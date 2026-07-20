import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var showImporter = false
    @State private var importSummary: String?
    @AppStorage("themePreference") private var themePreference = "system"

    /// Standard denominations offered in the plate inventory editor.
    private let plateChoices: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]

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
                    Stepper {
                        HStack {
                            Text("Bar weight")
                            Spacer()
                            Text("\(NSDecimalNumber(decimal: profile.barWeightKg).doubleValue.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                .monospacedDigit()
                        }
                    } onIncrement: {
                        profile.barWeightKg = min(30, profile.barWeightKg + Decimal(2.5))
                    } onDecrement: {
                        profile.barWeightKg = max(0, profile.barWeightKg - Decimal(2.5))
                    }
                    VStack(alignment: .leading, spacing: DT.Spacing.s8) {
                        Text("Available plates (kg, per side)")
                        HStack(spacing: DT.Spacing.s8 - 2) {
                            ForEach(plateChoices, id: \.self) { p in
                                let on = profile.availablePlatesKg.contains(p)
                                Button {
                                    if on {
                                        profile.availablePlatesKg.removeAll { $0 == p }
                                    } else {
                                        profile.availablePlatesKg.append(p)
                                    }
                                } label: {
                                    Text(p.formatted(.number.precision(.fractionLength(0...2))))
                                        .font(DT.Type.eyebrow)
                                        .monospacedDigit()
                                        .foregroundStyle(on ? DT.Colors.signal : DT.Colors.textTertiary)
                                        .padding(.horizontal, 7).padding(.vertical, 5)
                                        .background(on ? DT.Colors.signalDim : DT.Colors.surfaceInput)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(on ? DT.Colors.signal : DT.Colors.hairline))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("APPEARANCE") {
                    Picker("Theme", selection: $themePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
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
                    Button("Import CSV…") { showImporter = true }
                    if let importSummary {
                        Text(importSummary)
                            .font(DT.Type.secondary)
                            .foregroundStyle(DT.Colors.textSecondary)
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
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                switch result {
                case .success(let url): importCSV(from: url)
                case .failure: importSummary = "Import failed: couldn't open file"
                }
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

    /// Tolerant CSV import (§6): bad rows are skipped, good rows kept. Rows
    /// group into one completed session per calendar day; exercises match
    /// existing ones by canonical key or are created; PRs recompute after.
    private func importCSV(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importSummary = "Import failed: couldn't read file"
            return
        }
        let (rows, skipped) = CSVCodec.importCSV(text)
        guard !rows.isEmpty else {
            importSummary = "Nothing imported (\(skipped) rows skipped)"
            return
        }

        var exerciseByKey: [String: Exercise] = [:]
        for e in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            exerciseByKey[e.canonicalNameKey] = e
        }
        var touched: Set<String> = []
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.date) }

        for (day, dayRows) in byDay.sorted(by: { $0.key < $1.key }) {
            let session = WorkoutSession(name: "Imported \(day.formatted(date: .abbreviated, time: .omitted))",
                                         startedAt: dayRows.map(\.date).min() ?? day)
            session.endedAt = dayRows.map(\.date).max() ?? day
            session.status = .completed
            context.insert(session)

            var order = 0
            var byExercise: [String: SessionExercise] = [:]
            for row in dayRows.sorted(by: { $0.date < $1.date }) {
                let key = StrengthMath.canonicalNameKey(row.exercise)
                touched.insert(key)
                let exercise: Exercise
                if let existing = exerciseByKey[key] {
                    exercise = existing
                } else {
                    exercise = Exercise(name: row.exercise, isCustom: true)
                    context.insert(exercise)
                    exerciseByKey[key] = exercise
                }
                let se: SessionExercise
                if let existing = byExercise[key] {
                    se = existing
                } else {
                    se = SessionExercise(exercise: exercise, order: order)
                    order += 1
                    se.session = session
                    session.exercises?.append(se)
                    byExercise[key] = se
                }
                let set = SetEntry(index: se.sets?.count ?? 0, type: row.setType)
                set.weightKg = row.weightKg
                set.reps = row.reps
                set.rpe = row.rpe
                set.completedAt = row.date
                set.sessionExercise = se
                se.sets?.append(set)
            }
        }

        for key in touched {
            if let e = exerciseByKey[key] {
                try? InvalidationChain.recomputePRs(exercise: e, context: context)
            }
        }
        try? context.save()
        importSummary = "Imported \(rows.count) sets"
            + (skipped > 0 ? " · \(skipped) rows skipped" : "")
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
