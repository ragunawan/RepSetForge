import SwiftUI

/// Renders an RPG art asset with crisp nearest-neighbor scaling.
struct RPGSpriteView: View {
    let assetName: String
    var size: CGFloat = 64
    /// Optional compatibility flip. Current RPG source art is authored in
    /// final scene orientation: heroes face right, monsters/bosses face left.
    var flipped = false

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: flipped ? -1 : 1, y: 1)
    }
}

#Preview("Sprites") {
    VStack(spacing: 12) {
        HStack {
            ForEach(RPGClass.allCases) { rpgClass in
                RPGSpriteView(assetName: rpgClass.spriteFrame(.idle, index: 0), size: 48)
            }
        }
        HStack {
            RPGSpriteView(assetName: "rpg_monster_training_slime_idle0", size: 48)
            RPGSpriteView(assetName: "rpg_monster_goblin_warrior_idle0", size: 48)
            RPGSpriteView(assetName: "rpg_boss_iron_goblin_captain_idle0", size: 72)
        }
        HStack {
            RPGSpriteView(assetName: "rpg_equip_training_sword", size: 32)
            RPGSpriteView(assetName: "rpg_skill_power_strike", size: 32)
        }
    }
    .padding()
    .background(Color.questParchment)
}
