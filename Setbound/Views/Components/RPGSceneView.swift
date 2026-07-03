import SwiftUI
import SwiftData

/// The passive pixel RPG scene shown on the Quest Board (Home) tab. The hero
/// walks the training fields, auto-fights level-appropriate monsters, and is
/// locked against a milestone boss whenever one is active. Entirely passive —
/// no input required; real workout progress drives everything.
struct RPGSceneView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var characters: [PlayerCharacter]
    @Query(filter: #Predicate<Quest> { $0.completedDate != nil }) private var completedQuests: [Quest]
    @Query private var encounterStates: [RPGEncounterState]

    @State private var viewModel = RPGEncounterViewModel()

    private var snapshot: RPGProgressionSnapshot {
        guard let character = characters.first else { return RPGProgressionSnapshot() }
        return RPGProgressionSnapshot(
            character: character,
            completedQuestDates: completedQuests.compactMap(\.completedDate),
            state: encounterStates.first
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Image(viewModel.backgroundAsset)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .scaledToFill()

                HStack(alignment: .bottom) {
                    playerSprite
                    Spacer()
                    enemySprite
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(height: 160)
            .clipped()
            .overlay(alignment: .top) { combatTextOverlay.padding(.top, 8) }

            statusBar
        }
        .pixelPanel(fill: .questNavy, border: .questGold)
        .onAppear {
            viewModel.configure(snapshot: snapshot, state: encounterStates.first)
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: snapshot) { _, newValue in
            viewModel.configure(snapshot: newValue, state: encounterStates.first)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.start()
            } else {
                viewModel.stop()
            }
        }
    }

    // MARK: Hero

    private var playerSprite: some View {
        RPGSpriteView(assetName: viewModel.playerSpriteAsset, size: 64)
            .offset(x: viewModel.phase == .playerAttacking && !reduceMotion ? 6 : 0)
            .animation(.easeOut(duration: 0.15), value: viewModel.phase)
    }

    // MARK: Enemy

    @ViewBuilder
    private var enemySprite: some View {
        if let asset = viewModel.enemySpriteAsset {
            let size = viewModel.currentBoss?.displaySize
                ?? viewModel.currentMonster?.displaySize
                ?? 64
            enemyBody(asset: asset, size: size)
        }
    }

    private func enemyBody(asset: String, size: CGFloat) -> some View {
        let isHit = viewModel.phase == .enemyHit
        return RPGSpriteView(assetName: asset, size: size)
            .overlay(
                RPGSpriteView(assetName: asset, size: size)
                    .colorMultiply(.white)
                    .opacity(isHit ? 0.6 : 0)
                    .blendMode(.plusLighter)
            )
            .offset(x: isHit && !reduceMotion ? -5 : 0)
            .opacity(viewModel.phase == .enemyAppearing ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: viewModel.phase)
            .transition(.opacity)
    }

    // MARK: Combat text

    private var combatTextOverlay: some View {
        ZStack {
            ForEach(viewModel.combatEvents) { event in
                FloatingCombatText(event: event, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: SetboundMetrics.paddingSmall) {
            if viewModel.isBossFight {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.questGold)
            }
            Text(viewModel.statusText)
                .font(SetboundFont.body(12))
                .foregroundStyle(Color.questSilver)
                .lineLimit(1)
            Spacer()
            Text("Lv \(snapshot.currentLevel)")
                .font(SetboundFont.stat(12))
                .foregroundStyle(Color.questGold)
        }
        .padding(.horizontal, SetboundMetrics.paddingMedium)
        .padding(.vertical, SetboundMetrics.paddingSmall)
        .background(Color.questNavy)
    }
}

/// One floating combat text entry that drifts upward and fades. With Reduce
/// Motion it fades in place instead of moving.
private struct FloatingCombatText: View {
    let event: RPGCombatEvent
    let reduceMotion: Bool

    @State private var risen = false

    private var color: Color {
        switch event.kind {
        case .damage: return .questGold
        case .skill: return .cyan
        case .status: return .white
        }
    }

    var body: some View {
        Text(event.text)
            .font(SetboundFont.stat(13))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
            .offset(x: event.jitter, y: reduceMotion ? 0 : (risen ? -18 : 0))
            .opacity(risen ? 0.2 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { risen = true }
            }
    }
}

// MARK: - Previews

@MainActor
private func rpgPreviewContainer(
    level: Int,
    totalXP: Int = 0,
    completedWorkouts: Int = 0,
    state: RPGEncounterState = RPGEncounterState()
) -> ModelContainer {
    let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersistenceController.schema, configurations: [config])
    let context = container.mainContext
    let character = PlayerCharacter(
        level: level,
        totalXP: totalXP,
        title: ProgressionService.title(for: level),
        completedQuestCount: completedWorkouts
    )
    context.insert(character)
    context.insert(state)
    for index in 0..<completedWorkouts {
        let quest = Quest(name: "Training \(index + 1)", status: .completed)
        quest.completedDate = Calendar.current.date(byAdding: .day, value: -index, to: .now)
        context.insert(quest)
    }
    try? context.save()
    return container
}

#Preview("New Level 1 Hero") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(level: 1))
}

#Preview("Level 8 — Forest Enemies") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(level: 8, completedWorkouts: 3))
}

#Preview("Level 20 — Stronger Monsters") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(
            level: 20,
            completedWorkouts: 12,
            state: RPGEncounterState(
                completedBossIDs: ["iron_goblin_captain", "bone_colossus"],
                completedMilestoneQuestIDs: ["milestone_first_5_workouts", "milestone_7_day_streak"]
            )
        ))
}

#Preview("Active Boss Encounter") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(
            level: 10,
            completedWorkouts: 2,
            state: RPGEncounterState(
                activeBossID: "iron_goblin_captain",
                activeMilestoneQuestID: "milestone_first_5_workouts"
            )
        ))
}

#Preview("Boss Defeat (milestone met)") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(
            level: 10,
            completedWorkouts: 6,
            state: RPGEncounterState(
                activeBossID: "iron_goblin_captain",
                activeMilestoneQuestID: "milestone_first_5_workouts"
            )
        ))
}

#Preview("Level 55 — Endgame Monsters") {
    RPGSceneView()
        .padding()
        .modelContainer(rpgPreviewContainer(
            level: 55,
            totalXP: 25_000,
            completedWorkouts: 60,
            state: RPGEncounterState(
                completedBossIDs: RPGBossRegistry.all.map(\.id),
                completedMilestoneQuestIDs: RPGBossRegistry.milestoneQuests.map(\.id)
            )
        ))
}
