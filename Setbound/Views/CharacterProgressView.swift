import SwiftUI
import SwiftData

struct CharacterProgressView: View {
    @Query private var characters: [PlayerCharacter]
    @Query private var muscles: [MuscleProgress]

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SetboundMetrics.paddingLarge) {
                    if let character {
                        PixelStatPanel(
                            level: character.level,
                            title: character.title,
                            currentXP: character.currentXP,
                            nextLevelXP: character.nextLevelXP
                        )

                        HStack {
                            Text("Quests Completed")
                                .font(SetboundFont.body())
                            Spacer()
                            Text("\(character.completedQuestCount)")
                                .font(SetboundFont.stat())
                        }
                        .foregroundStyle(Color.questNavy)
                    }

                    if let buildInsight {
                        Text(buildInsight)
                            .font(SetboundFont.body(13))
                            .foregroundStyle(Color.questNavy.opacity(0.7))
                    }

                    PixelDivider()

                    Text("Muscle Groups")
                        .font(SetboundFont.heading())
                        .foregroundStyle(Color.questNavy)

                    LazyVGrid(columns: columns, spacing: SetboundMetrics.paddingMedium) {
                        ForEach(sortedMuscles) { muscle in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: muscle.muscleGroup.iconName)
                                        .foregroundStyle(Color.questGold)
                                    Text(muscle.muscleGroup.displayName)
                                        .font(SetboundFont.body(13))
                                        .foregroundStyle(Color.questSilver)
                                    Spacer()
                                    Text("L\(muscle.level)")
                                        .font(SetboundFont.stat(13))
                                        .foregroundStyle(Color.questGold)
                                }
                                PixelXPBar(currentXP: muscle.currentXP, maxXP: muscle.nextLevelXP, segmentCount: 6, height: 8)
                            }
                            .padding(SetboundMetrics.paddingSmall)
                            .pixelPanel()
                        }
                    }
                }
                .padding(SetboundMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("Character")
        }
    }
}

#Preview {
    CharacterProgressView()
        .modelContainer(PersistenceController.previewContainer)
}
