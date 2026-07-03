import SwiftUI
import UIKit

// MARK: - Color Extensions

extension Color {
    init(lightHex: String, darkHex: String) {
        let uiColor = UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned = cleaned.hasPrefix("#") ? String(cleaned.dropFirst()) : cleaned
            guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return .label }
            let r = CGFloat((value >> 16) & 0xFF) / 255
            let g = CGFloat((value >> 8) & 0xFF) / 255
            let b = CGFloat(value & 0xFF) / 255
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        }
        self.init(uiColor: uiColor)
    }

    // MARK: Semantic Palette

    /// Deep navy — primary panel/background color.
    static let questNavy = Color(lightHex: "1B2340", darkHex: "0B0F1F")

    /// Bright gold — primary accent, borders, XP fill.
    static let questGold = Color(lightHex: "D9A931", darkHex: "FFD34D")

    /// Silver — secondary text/borders on dark panels.
    static let questSilver = Color(lightHex: "C7CEDB", darkHex: "E4E8F0")

    /// RPG green — positive progress, unlocked states.
    static let questGreen = Color(lightHex: "2E8B57", darkHex: "4ADE80")

    /// Muted red — locked/incomplete states.
    static let questRed = Color(lightHex: "B03A3A", darkHex: "E05C5C")

    /// Parchment — light background wash behind panels.
    static let questParchment = Color(lightHex: "F4EFE2", darkHex: "14182B")
}

// MARK: - Typography

enum SetCraftFont {
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func heading(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Monospaced digits for XP/stat numbers so values don't jitter as they change.
    static func stat(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Layout Constants

enum SetCraftMetrics {
    /// Squared-off corner radius used throughout for the pixel-art look.
    static let cornerRadius: CGFloat = 6
    /// Chunky border width for panels and buttons.
    static let borderWidth: CGFloat = 3
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 14
    static let paddingLarge: CGFloat = 20
    static let xpBarSegmentSpacing: CGFloat = 2
}

// MARK: - View Modifiers

private struct PixelPanelModifier: ViewModifier {
    var fill: Color = .questNavy
    var border: Color = .questGold

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: SetCraftMetrics.cornerRadius, style: .circular))
            .overlay(
                RoundedRectangle(cornerRadius: SetCraftMetrics.cornerRadius, style: .circular)
                    .strokeBorder(border, lineWidth: SetCraftMetrics.borderWidth)
            )
    }
}

extension View {
    /// Chunky bordered "RPG panel" background used by pixel-art components.
    func pixelPanel(fill: Color = .questNavy, border: Color = .questGold) -> some View {
        modifier(PixelPanelModifier(fill: fill, border: border))
    }
}
