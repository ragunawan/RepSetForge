import SwiftUI

/// Segmented, blocky XP progress bar in the pixel-art style.
struct PixelXPBar: View {
    let currentXP: Int
    let maxXP: Int
    var fillColor: Color = .questGold
    var segmentCount: Int = 10
    var height: CGFloat = 14

    private var progress: Double {
        guard maxXP > 0 else { return 0 }
        return min(1, max(0, Double(currentXP) / Double(maxXP)))
    }

    var body: some View {
        HStack(spacing: SetboundMetrics.xpBarSegmentSpacing) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(segmentFilled(index) ? fillColor : Color.questNavy.opacity(0.3))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .circular))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .circular)
                .strokeBorder(Color.questSilver, lineWidth: 1.5)
        )
        .accessibilityLabel("XP progress")
        .accessibilityValue("\(currentXP) of \(maxXP)")
    }

    private func segmentFilled(_ index: Int) -> Bool {
        Double(index) < progress * Double(segmentCount)
    }
}

#Preview {
    VStack(spacing: 12) {
        PixelXPBar(currentXP: 30, maxXP: 100)
        PixelXPBar(currentXP: 340, maxXP: 800)
        PixelXPBar(currentXP: 0, maxXP: 100)
        PixelXPBar(currentXP: 100, maxXP: 100)
    }
    .padding()
    .background(Color.questParchment)
}
