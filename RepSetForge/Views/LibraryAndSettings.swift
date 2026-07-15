import SwiftData
import SwiftUI

struct LibraryView: View {
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var segment = "Routines"
    @State private var showingBuilder = false
    @State private var showingCreateExercise = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ScreenTitle(text: "Library")
                    Picker("Library", selection: $segment) {
                        Text("Routines").tag("Routines")
                        Text("Exercises").tag("Exercises")
                    }
                    .pickerStyle(.segmented)
                    if segment == "Routines" {
                        RoutineLibraryList(routines: routines, newRoutine: { showingBuilder = true })
                    } else {
                        ExerciseLibraryList(exercises: exercises, create: { showingCreateExercise = true })
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                Button(segment == "Routines" ? "New Routine" : "New Exercise") {
                    if segment == "Routines" {
                        showingBuilder = true
                    } else {
                        showingCreateExercise = true
                    }
                }
            }
            .sheet(isPresented: $showingBuilder) { RoutineBuilderView() }
            .sheet(isPresented: $showingCreateExercise) { CreateExerciseView() }
            .appBackground()
        }
    }
}

struct RoutineLibraryList: View {
    let routines: [Routine]
    let newRoutine: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Routines")
            if routines.isEmpty {
                EmptyStateCard(title: "No saved routines yet", message: "Build your first routine to unlock recommendations.", actionTitle: "New routine", action: newRoutine)
            } else {
                ForEach(routines) { routine in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name).font(RSTheme.mono(16, weight: .bold))
                        Text("\((routine.orderedItems ?? []).count) exercises · \(routine.lastPerformedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Never performed")").font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hairlineCard()
                }
            }
        }
    }
}

struct ExerciseLibraryList: View {
    let exercises: [Exercise]
    let create: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Exercises")
            if exercises.isEmpty {
                EmptyStateCard(title: "Create your first exercise", message: "The exercise database starts empty by design.", actionTitle: "Create exercise", action: create)
            } else {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exercise.name).font(RSTheme.mono(15, weight: .bold))
                                Text("\(exercise.primaryMuscle.title) · \(exercise.equipment.title)").font(RSTheme.mono(12)).foregroundStyle(RSTheme.textSecondary)
                            }
                            Spacer()
                            if exercise.isFavorite { Image(systemName: "star.fill").foregroundStyle(RSTheme.pr) }
                        }
                        .hairlineCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Exercise")
                    Text(exercise.name).font(RSTheme.mono(24, weight: .bold))
                    Text("\(exercise.primaryMuscle.title) · \(exercise.equipment.title)").foregroundStyle(RSTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .hairlineCard()
                ChartCard(title: "e1RM Trend", values: [0.3,0.4,0.35,0.55,0.7], insight: "More completed sessions will unlock stronger insights.")
                EmptyStateCard(title: "Recent sessions", message: "Completed sets for this exercise appear here.")
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .appBackground()
    }
}

struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var name = ""
    @State private var selected: [Exercise] = []
    @State private var showingPicker = false
    @State private var validation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") { TextField("Name", text: $name) }
                Section("Exercises") {
                    if selected.isEmpty { Text("Add at least one exercise.") }
                    ForEach(selected) { exercise in Text(exercise.name) }
                        .onMove { selected.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add exercise") { showingPicker = true }
                }
                if !validation.isEmpty { Text(validation).foregroundStyle(.red) }
            }
            .navigationTitle("Routine Builder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    selected.append(exercise)
                    showingPicker = false
                }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { validation = "Name is required."; return }
        guard !selected.isEmpty else { validation = "Add at least one exercise."; return }
        let items = selected.enumerated().map { RoutineItem(exercise: $0.element, order: $0.offset) }
        context.insert(Routine(name: name, items: items))
        try? context.save()
        dismiss()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var deleteText = ""
    @State private var showingDelete = false
    @State private var dataMessage = ""
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var exportedCSV = ""
    @State private var importCSV = ""
    @State private var bodyweight = 0.0
    @State private var bodyFat = 0.0

    private var settings: AppSettings { settingsRows.first ?? AppSettings() }
    private let csvService = CSVService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Training") {
                    Picker("Units", selection: Binding(get: { settings.units }, set: { settings.units = $0; try? context.save() })) {
                        ForEach(UnitSystem.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Default rest \(settings.defaultRestSeconds / 60):\(String(format: "%02d", settings.defaultRestSeconds % 60))", value: Binding(get: { settings.defaultRestSeconds }, set: { settings.defaultRestSeconds = $0; try? context.save() }), in: 30...300, step: 30)
                    Toggle("Show RPE column", isOn: Binding(get: { settings.showRPE }, set: { settings.showRPE = $0; try? context.save() }))
                    Stepper("Plate step \(settings.plateStepKg, specifier: "%.1f") kg", value: Binding(get: { settings.plateStepKg }, set: { settings.plateStepKg = $0; try? context.save() }), in: 0.5...10, step: 0.5)
                }
                Section("Data") {
                    Toggle("Auto-save to Apple Health", isOn: Binding(get: { settings.autoSaveToHealth }, set: { settings.autoSaveToHealth = $0; try? context.save() }))
                    Text("iCloud sync: available when signed into iCloud with the app container enabled.")
                    Button("Export CSV") {
                        exportedCSV = csvService.export(sessions: sessions)
                        showingExport = true
                    }
                    Button("Import CSV") { showingImport = true }
                    if !dataMessage.isEmpty {
                        Text(dataMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Body Metrics") {
                    TextField("Bodyweight kg", value: $bodyweight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                    TextField("Body fat %", value: $bodyFat, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                    Button("Log body metric", action: saveBodyMetric)
                        .disabled(bodyweight <= 0)
                }
                Section("Appearance") {
                    Picker("Theme", selection: Binding(get: { settings.theme }, set: { settings.theme = $0; try? context.save() })) {
                        ForEach(ThemePreference.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                Section {
                    Button("Delete all data", role: .destructive) { showingDelete = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showingExport) {
                NavigationStack {
                    TextEditor(text: $exportedCSV)
                        .font(RSTheme.mono(12))
                        .padding()
                        .navigationTitle("CSV Export")
                        .toolbar { Button("Done") { showingExport = false } }
                }
            }
            .sheet(isPresented: $showingImport) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paste rows with date, exercise, set_type, weight_kg, reps, and rpe columns.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $importCSV)
                            .font(RSTheme.mono(12))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(RSTheme.hairline))
                        Button("Validate import", action: validateImport)
                            .buttonStyle(RSButtonStyle(kind: .primary))
                    }
                    .padding()
                    .navigationTitle("CSV Import")
                    .toolbar { Button("Done") { showingImport = false } }
                }
            }
            .alert("Delete all data", isPresented: $showingDelete) {
                TextField("Type DELETE", text: $deleteText)
                Button("Delete", role: .destructive) {
                    if deleteText == "DELETE" { PersistenceController.resetAll(context: context) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes local SwiftData records and app-created workout state. Type DELETE to confirm.")
            }
        }
    }

    private func saveBodyMetric() {
        context.insert(BodyMetric(date: Date(), bodyweightKg: bodyweight, bodyFatPct: bodyFat > 0 ? bodyFat : nil))
        try? context.save()
        dataMessage = "Body metric logged."
        bodyweight = 0
        bodyFat = 0
    }

    private func validateImport() {
        do {
            let rows = try csvService.parseSets(from: importCSV)
            dataMessage = "\(rows.count) CSV set rows validated. Import review is ready."
            showingImport = false
        } catch {
            dataMessage = error.localizedDescription
        }
    }
}

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let healthMessage: String?
    @State private var showRoutineUpdate = false
    @State private var shareMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Workout complete")
                        Text(session.name).font(RSTheme.mono(24, weight: .bold))
                        HStack {
                            MetricTile(value: "\(Int(session.duration / 60))", label: "Minutes")
                            MetricTile(value: "\(session.completedSetCount)", label: "Sets")
                            MetricTile(value: "\(prCount)", label: "PRs", tint: RSTheme.pr)
                        }
                    }
                    .hairlineCard()
                    Text(healthMessage ?? "Apple Health save pending")
                        .font(RSTheme.mono(13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hairlineCard()
                    Button("Review routine updates") { showRoutineUpdate = true }.buttonStyle(RSButtonStyle(kind: .secondary))
                    Button("Share summary") { shareMessage = "\(session.name): \(session.completedSetCount) sets completed in RepSetForge." }
                        .buttonStyle(RSButtonStyle(kind: .quiet))
                    if !shareMessage.isEmpty {
                        Text(shareMessage)
                            .font(RSTheme.mono(12))
                            .foregroundStyle(RSTheme.textSecondary)
                            .hairlineCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Summary")
            .sheet(isPresented: $showRoutineUpdate) {
                RoutineUpdatePrompt(session: session)
            }
            .appBackground()
        }
    }

    private var prCount: Int { (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isPR).count }
}

struct RoutineUpdatePrompt: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @State private var updateWeights = true
    @State private var updateStructure = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Changes") {
                    Toggle("Apply weight changes", isOn: $updateWeights)
                    Toggle("Apply structural changes", isOn: $updateStructure)
                }
            }
            .navigationTitle("Update Routine")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
