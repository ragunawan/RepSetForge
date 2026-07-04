import SwiftUI

/// Chunky bordered button style for quest actions, matching the pixel-art theme.
struct PixelButtonStyle: ButtonStyle {
    var tint: Color = .questGold
    var textColor: Color = .questNavy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RepSetForgeFont.heading())
            .foregroundStyle(textColor)
            .padding(.horizontal, RepSetForgeMetrics.paddingLarge)
            .padding(.vertical, RepSetForgeMetrics.paddingSmall)
            .background(tint.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadius, style: .circular))
            .overlay(
                RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadius, style: .circular)
                    .strokeBorder(Color.questNavy, lineWidth: RepSetForgeMetrics.borderWidth)
            )
            // Deliberately not gated behind Reduce Motion: this is a tiny
            // (3%) squish synchronous with the touch itself, not an
            // independent animation — the same category of feedback system
            // buttons keep regardless of the setting. Reduce Motion targets
            // parallax/movement that plays out on its own; see
            // RepSetForgeTheme.swift's spec comment for where that line is drawn.
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static var pixel: PixelButtonStyle { PixelButtonStyle() }
    static func pixel(tint: Color, textColor: Color = .questNavy) -> PixelButtonStyle {
        PixelButtonStyle(tint: tint, textColor: textColor)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button("Begin Quest") {}
            .buttonStyle(.pixel)
        Button("Complete Quest") {}
            .buttonStyle(.pixel(tint: .questGreen, textColor: .white))
    }
    .padding()
    .background(Color.questParchment)
}
