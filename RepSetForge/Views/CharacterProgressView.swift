import SwiftUI
import SwiftData

struct CharacterProgressView: View {
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]
    @Query(sort: \PersonalRecord.achievedDate, order: .reverse) private var personalRecords: [PersonalRecord]

    private var character: PlayerCharacter? { characters.first }

    private var sortedMuscles: [MuscleProgress] {
        muscles.sorted { lhs, rhs in
            let order = MuscleGroup.allCases
            let li = order.firstIndex(of: lhs.muscleGroup) ?? 0
            let ri = order.firstIndex(of: rhs.muscleGroup) ?? 0
            return li < ri
        }
    }

    private var buildInsight: String? {
        guard let strongest = sortedMuscles.max(by: { $0.totalXP < $1.totalXP }), strongest.totalXP > 0 else {
            return nil
        }
        return "Your build leans \(strongest.muscleGroup.displayName)-dominant so far."
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

                    if let buildInsight {
                        Text(buildInsight)
                            .font(RepSetForgeFont.body(13))
                            .foregroundStyle(Color.questNavy.opacity(0.7))
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
}

private struct SettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var characters: [PlayerCharacter]

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
        }
    }
}

#Preview {
    CharacterProgressView()
        .modelContainer(PersistenceController.previewContainer)
}
