import SwiftUI

/// RPG medal-shaped badge icon used for achievements.
struct PixelBadge: View {
    let iconName: String
    let unlocked: Bool
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SetboundMetrics.cornerRadius, style: .circular)
                .fill(unlocked ? Color.questGold : Color.questNavy.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: SetboundMetrics.cornerRadius, style: .circular)
                        .strokeBorder(unlocked ? Color.questSilver : Color.questRed.opacity(0.6), lineWidth: 2.5)
                )
            Image(systemName: unlocked ? iconName : "lock.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(unlocked ? Color.questNavy : Color.questSilver.opacity(0.6))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        PixelBadge(iconName: "flag.checkered", unlocked: true)
        PixelBadge(iconName: "star.circle.fill", unlocked: false)
    }
    .padding()
    .background(Color.questParchment)
}
