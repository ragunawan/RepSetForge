import SwiftUI

/// Chunky bordered button style for quest actions, matching the pixel-art theme.
struct PixelButtonStyle: ButtonStyle {
    var tint: Color = .questGold
    var textColor: Color = .questNavy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SetboundFont.heading())
            .foregroundStyle(textColor)
            .padding(.horizontal, SetboundMetrics.paddingLarge)
            .padding(.vertical, SetboundMetrics.paddingSmall)
            .background(tint.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: SetboundMetrics.cornerRadius, style: .circular))
            .overlay(
                RoundedRectangle(cornerRadius: SetboundMetrics.cornerRadius, style: .circular)
                    .strokeBorder(Color.questNavy, lineWidth: SetboundMetrics.borderWidth)
            )
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
