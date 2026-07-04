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

enum RepSetForgeFont {
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

enum RepSetForgeMetrics {
    /// Squared-off corner radius used throughout for the pixel-art look.
    static let cornerRadius: CGFloat = 6
    /// Chunky border width for panels and buttons.
    static let borderWidth: CGFloat = 3
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 14
    static let paddingLarge: CGFloat = 20
    static let xpBarSegmentSpacing: CGFloat = 2
}

// MARK: - Pixel-Art Visual Spec
//
// The canonical reference for RepSetForge's visual language — read this
// before adding new UI so new work matches what's already established
// rather than introducing a one-off style.
//
// Palette usage (see the Color extension above):
//   - questNavy: primary panel/background fill — the dark slate every RPG
//     panel sits on.
//   - questGold: primary accent — borders, XP fill, and anything that should
//     read as "important" or "earned."
//   - questSilver: secondary text on dark panels (labels, detail text) —
//     not used for borders or as an accent color.
//   - questGreen / questRed: semantic only (positive/unlocked vs.
//     locked/incomplete) — never used decoratively.
//   - questParchment: the light background wash behind panels, not the
//     fill inside them.
//
// Typography usage (see RepSetForgeFont below):
//   - .title: rare, only for full-screen headers below `.navigationTitle`.
//   - .heading: section headers and card titles.
//   - .body: everything else — labels, descriptions, detail text.
//   - .stat: numbers that change often (XP, levels, countdowns) —
//     monospaced digits so layout doesn't jitter as values update.
//
// Borders, corners, shadows:
//   - `RepSetForgeMetrics.cornerRadius` (6pt) and `.borderWidth` (3pt) are
//     the two knobs behind the "chunky pixel-art panel" look. Use
//     `pixelPanel()` rather than hand-rolling a bordered RoundedRectangle.
//   - Text over busy art (combat numbers, etc.) uses `pixelTextShadow()` — a
//     hard, zero-blur 1pt offset shadow. Never a soft/blurred shadow; that
//     reads as a modern flat-UI effect, not pixel art.
//
// Icon/sprite grid sizes — see `ArtSource/RPG/README.md`'s "Size Summary"
// table for the authoritative per-category numbers (it's the source of
// truth the importer validates against). Every sprite is authored on a
// native pixel grid and exported at a fixed multiple for crisp
// nearest-neighbor scaling (`RPGSpriteView` always sets `.interpolation(.none)`):
//   Hero/class sprite     64x64   → 256x256
//   Small monster         48x48   → 192x192
//   Medium monster        64x64   → 256x256
//   Large monster         80x80   → 320x320
//   Boss                 128x128  → 512x512
//   Equipment/Skill icon   48x48  → 192x192
//   Background           480x270  → 960x540

// MARK: - View Modifiers

private struct PixelPanelModifier: ViewModifier {
    var fill: Color = .questNavy
    var border: Color = .questGold

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadius, style: .circular))
            .overlay(
                RoundedRectangle(cornerRadius: RepSetForgeMetrics.cornerRadius, style: .circular)
                    .strokeBorder(border, lineWidth: RepSetForgeMetrics.borderWidth)
            )
    }
}

extension View {
    /// Chunky bordered "RPG panel" background used by pixel-art components.
    func pixelPanel(fill: Color = .questNavy, border: Color = .questGold) -> some View {
        modifier(PixelPanelModifier(fill: fill, border: border))
    }

    /// Hard, zero-blur drop shadow for text over busy art — the pixel-art
    /// alternative to a soft/blurred shadow, which would break the aesthetic.
    func pixelTextShadow(opacity: Double = 0.8) -> some View {
        shadow(color: .black.opacity(opacity), radius: 0, x: 1, y: 1)
    }
}
