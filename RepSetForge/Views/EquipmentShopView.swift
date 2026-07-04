import SwiftUI
import SwiftData

/// Browse the equipment catalog, buy items with gold, and equip/unequip per
/// slot. Shown as its own "Gear" tab.
struct EquipmentShopView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var characters: [PlayerCharacter]
    @Query private var encounterStates: [RPGEncounterState]
    @Query private var ownedRecords: [OwnedEquipment]
    @Query private var skillRecords: [SkillProgress]

    @State private var toastMessage: String?

    private var character: PlayerCharacter? { characters.first }
    private var rpgClass: RPGClass { encounterStates.first?.rpgClass ?? .knight }

    private var itemsBySlot: [(slot: RPGEquipmentSlot, items: [RPGEquipment])] {
        RPGEquipmentSlot.allCases.map { slot in
            (slot, RPGEquipmentRegistry.all.filter { $0.slot == slot }.sorted { $0.requiredLevel < $1.requiredLevel })
        }
    }

    private var skillsByCategory: [(category: RPGSkillCategory, skills: [RPGSkill])] {
        RPGSkillCategory.allCases.map { category in
            let skills = RPGSkillRegistry.all
                .filter { $0.category == category && $0.classes.contains(rpgClass) }
                .sorted { $0.unlockThresholdXP < $1.unlockThresholdXP }
            return (category, skills)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingLarge) {
                    if let character {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(Color.questGold)
                            Text("\(character.gold) Gold")
                                .font(RepSetForgeFont.stat())
                                .foregroundStyle(Color.questNavy)
                            Spacer()
                            Text("Level \(character.level) \(rpgClass.displayName)")
                                .font(RepSetForgeFont.body(13))
                                .foregroundStyle(Color.questNavy.opacity(0.7))
                        }
                    }

                    if let toastMessage {
                        Text(toastMessage)
                            .font(RepSetForgeFont.body(12))
                            .foregroundStyle(Color.questGreen)
                    }

                    ForEach(itemsBySlot, id: \.slot) { entry in
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text(entry.slot.displayName)
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(entry.items) { item in
                                EquipmentRow(
                                    item: item,
                                    state: rowState(for: item),
                                    onBuy: { buy(item) },
                                    onEquip: { equip(item) }
                                )
                            }
                        }
                    }

                    PixelDivider()

                    Text("Skills")
                        .font(RepSetForgeFont.title(18))
                        .foregroundStyle(Color.questNavy)
                    Text("Skills unlock from real training — the muscles that feed each one are shown below. Equip one per category to drive passive combat.")
                        .font(RepSetForgeFont.body(12))
                        .foregroundStyle(Color.questNavy.opacity(0.7))

                    ForEach(skillsByCategory, id: \.category) { entry in
                        VStack(alignment: .leading, spacing: RepSetForgeMetrics.paddingSmall) {
                            Text(entry.category.displayName)
                                .font(RepSetForgeFont.heading())
                                .foregroundStyle(Color.questNavy)
                            ForEach(entry.skills) { skill in
                                SkillRow(
                                    skill: skill,
                                    progress: skillProgress(for: skill),
                                    onEquip: { equipSkill(skill) }
                                )
                            }
                        }
                    }
                }
                .padding(RepSetForgeMetrics.paddingLarge)
            }
            .background(Color.questParchment.ignoresSafeArea())
            .navigationTitle("Equipment")
        }
    }

    enum RowState {
        case equipped
        case owned
        case levelLocked
        case insufficientGold
        case buyable
    }

    private func rowState(for item: RPGEquipment) -> RowState {
        guard let character else { return .levelLocked }
        guard item.isUsable(by: rpgClass, atLevel: character.level) else { return .levelLocked }

        if let record = ownedRecords.first(where: { $0.equipmentID == item.id && $0.owned }) {
            return record.equipped ? .equipped : .owned
        }
        return character.gold >= item.price ? .buyable : .insufficientGold
    }

    private func buy(_ item: RPGEquipment) {
        let result = RPGEquipmentService.purchase(item.id, context: modelContext)
        try? modelContext.save()
        switch result {
        case .success: toastMessage = "Bought \(item.name)!"
        case .alreadyOwned: toastMessage = "You already own \(item.name)."
        case .insufficientGold: toastMessage = "Not enough gold for \(item.name)."
        case .levelLocked: toastMessage = "\(item.name) unlocks at level \(item.requiredLevel)."
        case .notFound: toastMessage = nil
        }
    }

    private func equip(_ item: RPGEquipment) {
        RPGEquipmentService.equip(item.id, context: modelContext)
        try? modelContext.save()
    }

    private func skillProgress(for skill: RPGSkill) -> SkillProgress? {
        skillRecords.first { $0.skillID == skill.id }
    }

    private func equipSkill(_ skill: RPGSkill) {
        SkillProgressionService.equip(skill.id, context: modelContext)
        try? modelContext.save()
    }
}

private struct EquipmentRow: View {
    let item: RPGEquipment
    let state: EquipmentShopView.RowState
    let onBuy: () -> Void
    let onEquip: () -> Void

    private var rarityColor: Color {
        switch item.rarity {
        case .common: return .questSilver
        case .uncommon: return .questGreen
        case .rare: return .questGold
        case .epic: return .questRed
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(RepSetForgeFont.heading(15))
                        .foregroundStyle(Color.questSilver)
                    Text(item.rarity.displayName)
                        .font(RepSetForgeFont.body(10))
                        .foregroundStyle(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(rarityColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(item.flavor)
                    .font(RepSetForgeFont.body(12))
                    .foregroundStyle(Color.questSilver.opacity(0.7))
                Text("Requires Level \(item.requiredLevel)")
                    .font(RepSetForgeFont.body(11))
                    .foregroundStyle(Color.questSilver.opacity(0.5))
            }
            Spacer()
            actionButton
        }
        .padding(RepSetForgeMetrics.paddingSmall)
        .pixelPanel(border: state == .equipped ? .questGold : .questGold.opacity(0.3))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .equipped:
            Label("Equipped", systemImage: "checkmark.seal.fill")
                .font(RepSetForgeFont.body(12))
                .foregroundStyle(Color.questGreen)
        case .owned:
            Button("Equip", action: onEquip)
                .buttonStyle(.pixel(tint: .questGreen, textColor: .white))
        case .levelLocked:
            Label("Locked", systemImage: "lock.fill")
                .font(RepSetForgeFont.body(12))
                .foregroundStyle(Color.questRed)
        case .insufficientGold:
            Text("\(item.price) Gold")
                .font(RepSetForgeFont.stat(13))
                .foregroundStyle(Color.questRed)
        case .buyable:
            Button("\(item.price) Gold", action: onBuy)
                .buttonStyle(.pixel)
        }
    }
}

private struct SkillRow: View {
    let skill: RPGSkill
    let progress: SkillProgress?
    let onEquip: () -> Void

    private var isUnlocked: Bool { progress?.unlocked ?? false }
    private var isEquipped: Bool { isUnlocked && (progress?.equipped ?? false) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(RepSetForgeFont.heading(15))
                    .foregroundStyle(Color.questSilver)
                Text(skill.detail)
                    .font(RepSetForgeFont.body(12))
                    .foregroundStyle(Color.questSilver.opacity(0.7))
                if !isUnlocked {
                    Text("\(progress?.totalXP ?? 0) / \(skill.unlockThresholdXP) XP to unlock")
                        .font(RepSetForgeFont.body(11))
                        .foregroundStyle(Color.questSilver.opacity(0.5))
                }
            }
            Spacer()
            actionButton
        }
        .padding(RepSetForgeMetrics.paddingSmall)
        .pixelPanel(border: isEquipped ? .questGold : .questGold.opacity(0.3))
    }

    @ViewBuilder
    private var actionButton: some View {
        if isEquipped {
            Label("Equipped", systemImage: "checkmark.seal.fill")
                .font(RepSetForgeFont.body(12))
                .foregroundStyle(Color.questGreen)
        } else if isUnlocked {
            Button("Equip", action: onEquip)
                .buttonStyle(.pixel(tint: .questGreen, textColor: .white))
        } else {
            Label("Locked", systemImage: "lock.fill")
                .font(RepSetForgeFont.body(12))
                .foregroundStyle(Color.questRed)
        }
    }
}

#Preview {
    EquipmentShopView()
        .modelContainer(PersistenceController.previewContainer)
}
