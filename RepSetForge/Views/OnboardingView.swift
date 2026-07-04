import SwiftUI
import SwiftData

/// First-run introduction to RepSetForge's concept: choose a hero class and
/// weight unit before starting the first quest. Shown exactly once, driven by
/// `PlayerCharacter.hasCompletedOnboarding`. Muscle/achievement/player state
/// is already seeded once by `PersistenceController.seedCoreDataIfNeeded()`
/// before this view ever appears; this flow just captures the two choices
/// that are meaningful to make up front (class, units).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @Query private var encounterStates: [RPGEncounterState]

    @State private var selectedClass: RPGClass = .knight
    @State private var selectedUnit: WeightUnit = .pounds

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
                    VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.questGold)
                        Text("Welcome to RepSetForge")
                            .font(RepSetForgeFont.title())
                            .foregroundStyle(Color.questNavy)
                            .multilineTextAlignment(.center)
                        Text("Every workout is a quest. Log sets to earn XP, level up your character and muscle groups, unlock achievements, and watch your hero grow stronger.")
                            .font(RepSetForgeFont.body(14))
                            .foregroundStyle(Color.questNavy.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    PixelDivider()

                    Text("Choose Your Class")
                        .font(RepSetForgeFont.heading())
                        .foregroundStyle(Color.questNavy)

                    VStack(spacing: RepSetForgeMetrics.paddingSmall) {
                        ForEach(RPGClass.allCases) { rpgClass in
                            classRow(rpgClass)
                        }
                    }

                    PixelDivider()

                    Text("Weight Units")
                        .font(RepSetForgeFont.heading())
                        .foregroundStyle(Color.questNavy)

                    Picker("Weight Unit", selection: $selectedUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Begin Your Quest") {
                        completeOnboarding()
                    }
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, RepSetForgeMetrics.paddingMedium)
                }
                .padding(RepSetForgeMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
        }
        .interactiveDismissDisabled()
    }

    private func classRow(_ rpgClass: RPGClass) -> some View {
        let isSelected = selectedClass == rpgClass
        return Button {
            selectedClass = rpgClass
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rpgClass.displayName)
                        .font(RepSetForgeFont.heading(15))
                        .foregroundStyle(Color.questSilver)
                    Text(rpgClass.flavor)
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(Color.questSilver.opacity(0.7))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.questGold)
                }
            }
            .padding(RepSetForgeMetrics.paddingSmall)
            .pixelPanel(border: isSelected ? .questGold : .questGold.opacity(0.3))
        }
        .buttonStyle(.plain)
    }

    private func completeOnboarding() {
        if let character = characters.first {
            character.preferredWeightUnit = selectedUnit
            character.hasCompletedOnboarding = true
        }
        if let encounterState = encounterStates.first {
            encounterState.rpgClass = selectedClass
        }
        RPGEquipmentService.seedStarterGear(for: selectedClass, context: modelContext)
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PersistenceController.previewContainer)
}
