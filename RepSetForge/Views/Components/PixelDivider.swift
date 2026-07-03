import SwiftUI

/// Decorative pixel-art divider — a row of chunky gold blocks.
struct PixelDivider: View {
    var color: Color = .questGold

    var body: some View {
        GeometryReader { geometry in
            let blockWidth: CGFloat = 6
            let spacing: CGFloat = 4
            let count = max(1, Int(geometry.size.width / (blockWidth + spacing)))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { _ in
                    Rectangle()
                        .fill(color.opacity(0.7))
                        .frame(width: blockWidth, height: 3)
                }
            }
        }
        .frame(height: 3)
    }
}

#Preview {
    PixelDivider()
        .padding()
        .background(Color.questParchment)
}
