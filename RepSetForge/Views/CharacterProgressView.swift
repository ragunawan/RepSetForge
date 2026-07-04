import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CharacterProgressView: View {
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]
    @Query(sort: \PersonalRecord.achievedDate, order: .reverse) private var personalRecords: [PersonalRecord]
    @Query(sort: \Quest.completedDate, order: .reverse) private var allQuests: [Quest]

    private var character: PlayerCharacter? { characters.first }

    private var sortedMuscles: [MuscleProgress] {
        muscles.sorted { lhs, rhs in
            let order = MuscleGroup.allCases
            let li = order.firstIndex(of: lhs.muscleGroup) ?? 0
            let ri = order.firstIndex(of: rhs.muscleGroup) ?? 0
            return li < ri
        }
    }

    private var trainingStyle: TrainingStyle {
        TrainingStyleService.style(for: muscles)
    }

    private var insights: [TrainingInsightsService.Insight] {
        TrainingInsightsService.insights(for: muscles)
    }

    private var recoveryStats: [MuscleLoadStat] {
        MuscleRecoveryService.loadStats(from: allQuests)
    }

    private var recoveryRecommendation: RecoveryRecommendation {
        RecoveryRecommendationService.recommendation(from: allQuests)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
                    if let character {
                        PixelStatPanel(
                            level: character.level,
                            title: character.title,
                            currentXP: character.currentXP,
                            nextLevelXP: character.nextLevelXP
                        )

                        HStack {
                            Text("Quests Completed")
                                .font(RepSetForgeFont.body())
                            Spacer()
                            Text("\(character.completedQuestCount)")
                                .font(RepSetForgeFont.stat())
                        }
                        .foregroundStyle(Color.questNavy)

                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(Color.questGold)
                            Text("Gold")
                                .font(RepSetForgeFont.body())
                            Spacer()
                            Text("\(character.gold)")
                                .font(RepSetForgeFont.stat())
                        }
                        .foregroundStyle(Color.questNavy)
                    }

                    if trainingStyle != .freshRecruit {
                        HStack(spacing: RepSetForgeMetrics.paddingSmall) {
                            Image(systemName: trainingStyle.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.questNavy)
                                .frame(width: 32, height: 32)
                                .background(Color.questGold)
                                .clipShape(RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadius, style: .circular))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trainingStyle.displayName)
                                    .font(RepSetForgeFont.heading(14))
                                    .foregroundStyle(Color.questNavy)
                                Text(trainingStyle.detail)
                                    .font(RepSetForgeFont.body(12))
                                    .foregroundStyle(Color.questNavy.opacity(0.7))
                            }
                            Spacer()
                        }
                    }

                    PixelDivider()

                    Text("Muscle Groups")
                        .font(RepSetForgeFont.heading())
                        .foregroundStyle(Color.questNavy)

                    LazyVGrid(columns: columns, spacing: RepSetForgeMetrics.paddingMedium) {
                        ForEach(sortedMuscles) { muscle in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: muscle.muscleGroup.iconName)
                                        .foregroundStyle(Color.questGold)
                                    Text(muscle.muscleGroup.displayName)
                                        .font(RepSetForgeFont.body(13))
                                        .foregroundStyle(Color.questSilver)
                                    Spacer()
                                    Text("L\(muscle.level)")
                                        .font(RepSetForgeFont.stat(13))
                                        .foregroundStyle(Color.questGold)
                                }
                                PixelXPBar(currentXP: muscle.currentXP, maxXP: muscle.nextLevelXP, segmentCount: 6, height: 8)
                            }
                            .padding(RepSetForgeMetrics.paddingSmall)
                            .pixelPanel()
                        }
                    }

                    if recoveryRecommendation != .allClear {
                        PixelDivider()

                        HStack(alignment: .top, spacing: RepSetForgeMetrics.paddingSmall) {
                            Image(systemName: recoveryRecommendation.iconName)
                                .foregroundStyle(Color.questGold)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recoveryRecommendation.title)
                                    .font(RepSetForgeFont.body(13))
                                    .foregroundStyle(Color.questSilver)
                                Text(recoveryRecommendation.detail)
                                    .font(RepSetForgeFont.body(12))
                                    .foregroundStyle(Color.questSilver.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(RepSetForgeMetrics.paddingSmall)
                        .pixelPanel()
                    }

                    if !recoveryStats.isEmpty {
                        PixelDivider()

                        Text("Recovery")
                            .font(RepSetForgeFont.heading())
                            .foregroundStyle(Color.questNavy)

                        LazyVGrid(columns: columns, spacing: RepSetForgeMetrics.paddingMedium) {
                            ForEach(recoveryStats) { stat in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: stat.muscleGroup.iconName)
                                            .foregroundStyle(recoveryColor(for: stat.status))
                                        Text(stat.muscleGroup.displayName)
                                            .font(RepSetForgeFont.body(13))
                                            .foregroundStyle(Color.questSilver)
                                    }
                                    Text(stat.status.rawValue)
                                        .font(RepSetForgeFont.stat(12))
                                        .foregroundStyle(recoveryColor(for: stat.status))
                                    Text(recoveryDetail(for: stat))
                                        .font(RepSetForgeFont.body(11))
                                        .foregroundStyle(Color.questSilver.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel(fill: recoveryColor(for: stat.status).opacity(0.18))
                            }
                        }
                    }

                    if !insights.isEmpty {
                        PixelDivider()

                        Text("Insights")
                            .font(RepSetForgeFont.heading())
                            .foregroundStyle(Color.questNavy)

                        VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                            ForEach(insights) { insight in
                                HStack(alignment: .top) {
                                    Image(systemName: insight.iconName)
                                        .foregroundStyle(Color.questGold)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(insight.title)
                                            .font(RepSetForgeFont.body(13))
                                            .foregroundStyle(Color.questSilver)
                                        Text(insight.detail)
                                            .font(RepSetForgeFont.body(12))
                                            .foregroundStyle(Color.questSilver.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel()
                            }
                        }
                    }

                    if !personalRecords.isEmpty {
                        PixelDivider()

                        Text("Personal Records")
                            .font(RepSetForgeFont.heading())
                            .foregroundStyle(Color.questNavy)

                        VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                            ForEach(personalRecords) { record in
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(Color.questGold)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.exerciseName)
                                            .font(RepSetForgeFont.body(13))
                                            .foregroundStyle(Color.questSilver)
                                        Text(record.recordType.displayName)
                                            .font(RepSetForgeFont.body(11))
                                            .foregroundStyle(Color.questSilver.opacity(0.7))
                                    }
                                    Spacer()
                                    Text(record.recordType.formattedValue(record.value, unit: record.weightUnit ?? .pounds))
                                        .font(RepSetForgeFont.stat(13))
                                        .foregroundStyle(Color.questGold)
                                }
                                .padding(RepSetForgeMetrics.paddingSmall)
                                .pixelPanel()
                            }
                        }
                    }
                }
                .padding(RepSetForgeMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
        }
    }

    private func recoveryColor(for status: RecoveryStatus) -> Color {
        switch status {
        case .untrained: return Color.questSilver
        case .fatigued: return .red
        case .recovering: return .orange
        case .fresh: return .green
        }
    }

    private func recoveryDetail(for stat: MuscleLoadStat) -> String {
        switch stat.daysSinceLastTrained {
        case nil: return "Never trained"
        case 0: return "Trained today"
        case 1: return "1 day ago"
        case let days?: return "\(days) days ago"
        }
    }
}

private struct SettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]
    @Query private var allQuests: [Quest]
    @Query private var personalRecords: [PersonalRecord]
    @Query private var achievements: [Achievement]

    @State private var exportFormat: ProgressExportFormat = .json
    @State private var exportedFileURL: URL?
    @State private var exportError: String?
    @State private var showingImporter = false
    @State private var importResultMessage: String?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                if let character = characters.first {
                    Section("Units") {
                        Picker("Weight Unit", selection: Binding(
                            get: { character.preferredWeightUnit },
                            set: { character.preferredWeightUnit = $0 }
                        )) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                    Section {
                        Text("Only affects new sets you log — sets you've already recorded keep displaying in the unit you entered them in.")
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ProgressExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .onChange(of: exportFormat) { exportedFileURL = nil }

                    if let exportedFileURL {
                        ShareLink(item: exportedFileURL) {
                            Label("Share Export", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Prepare Export") { prepareExport() }
                    }

                    if let exportError {
                        Text(exportError)
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(.red)
                    }

                    Button("Import Progress…") { showingImporter = true }

                    if let importResultMessage {
                        Text(importResultMessage)
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(Color.questNavy.opacity(0.7))
                    }
                }

                if HealthKitService.isAvailable {
                    Section("Apple Health") {
                        Button("Connect to Apple Health") {
                            Task { try? await HealthKitService.requestAuthorization() }
                        }
                        Text("Completed quests are saved to Health as workouts with an estimated active-energy value. RepSetForge has no wearable sensor, so this is an estimate, not a measured figure.")
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Privacy & Data") {
                    Text("RepSetForge stores everything — quests, exercises, sets, achievements, and personal records — only on this device. Nothing is sent to any RepSetForge server, because there isn't one. Data only ever leaves the device when you explicitly export it, or if you connect Apple Health above.")
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(.secondary)

                    Button("Delete All Workout Data", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    Text("Erases every quest, exercise, and set, and resets your level, muscle progress, gold, achievements, and personal records to their starting state. Your class, equipment, and weight-unit preference are untouched.")
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Delete All Workout Data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    PrivacyDataService.deleteAllWorkoutData(context: modelContext)
                }
            } message: {
                Text("This can't be undone. Every quest, exercise, and set will be erased, and your progression will reset to Level 1.")
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let importResult = try ProgressImportService.importExport(from: data, context: modelContext)
                try? modelContext.save()
                importResultMessage = "Imported \(importResult.importedQuestCount) quest(s); skipped \(importResult.skippedDuplicateQuestCount) already present."
            } catch {
                importResultMessage = error.localizedDescription
            }
        case .failure(let error):
            importResultMessage = error.localizedDescription
        }
    }

    private func prepareExport() {
        exportError = nil
        let export = ProgressExportService.makeExport(
            character: characters.first,
            muscles: muscles,
            quests: allQuests,
            personalRecords: personalRecords,
            achievements: achievements
        )

        let dateStamp = ISO8601DateFormatter().string(from: .now).prefix(10)
        let filename = "RepSetForge-Export-\(dateStamp).\(exportFormat.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            switch exportFormat {
            case .json:
                let data = try ProgressExportService.json(from: export)
                try data.write(to: fileURL, options: .atomic)
            case .csv:
                let csv = ProgressExportService.csv(from: export)
                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            exportedFileURL = fileURL
        } catch {
            exportError = "Couldn't prepare the export: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CharacterProgressView()
        .modelContainer(PersistenceController.previewContainer)
}
