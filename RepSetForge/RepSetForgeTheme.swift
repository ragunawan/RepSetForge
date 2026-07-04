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
    /// Scales a fixed point size by the current Dynamic Type setting, the
    /// same mechanism `Font.system(.body)` uses internally — lets every
    /// `RepSetForgeFont` call site keep its exact size *as designed at the
    /// default content size category* while still growing/shrinking for
    /// users who've changed their text-size preference. Must be called
    /// during body evaluation (not cached) so it re-resolves whenever the
    /// environment's content size category changes.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        UIFontMetrics.default.scaledValue(for: size)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: scaled(size), weight: .heavy, design: .rounded)
    }

    static func heading(_ size: CGFloat = 17) -> Font {
        .system(size: scaled(size), weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: scaled(size), weight: .medium, design: .rounded)
    }

    /// Monospaced digits for XP/stat numbers so values don't jitter as they change.
    static func stat(_ size: CGFloat = 15) -> Font {
        .system(size: scaled(size), weight: .bold, design: .monospaced)
    }
}

// MARK: - Layout Constants

enum RepSetForgeMetrics {
    /// Squared-off corner radius used throughout for the pixel-art look.
    static let cornerRadius: CGFloat = 6
    /// Scaled-down corner radius for small elements (XP bar ends, status
    /// stripes, inline pill-style badges) where the full `cornerRadius`
    /// would look disproportionately rounded.
    static let cornerRadiusSmall: CGFloat = 3
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
//   - All four scale with Dynamic Type automatically (via `UIFontMetrics`) —
//     never bypass `RepSetForgeFont` for a raw `.system(size:)` call, or
//     that text silently stops scaling for users with larger text sizes.
//
// Borders, corners, shadows:
//   - `RepSetForgeMetrics.cornerRadius` (6pt) and `.borderWidth` (3pt) are
//     the two knobs behind the "chunky pixel-art panel" look. Use
//     `pixelPanel()` rather than hand-rolling a bordered RoundedRectangle.
//   - `.cornerRadiusSmall` (3pt) is the same squared-off language scaled down
//     for small elements (XP bar ends, status stripes, inline badges) — but
//     always a `RoundedRectangle`, never a fully-rounded `Capsule`. A capsule
//     reads as generic flat-UI chrome, not pixel art.
//   - Text over busy art (combat numbers, etc.) uses `pixelTextShadow()` — a
//     hard, zero-blur 1pt offset shadow. Never a soft/blurred shadow; that
//     reads as a modern flat-UI effect, not pixel art.
//
// Animation:
//   - Freshly-earned reward lists (XP rows, level-ups, achievement unlocks)
//     use `staggeredAppearance(index:)` for a lightweight cascading reveal —
//     never a single all-at-once fade. It already no-ops under Reduce
//     Motion, so call sites don't need their own reduceMotion branch for it.
//   - Anything else worth animating (set-complete checkmarks, etc.) should
//     still check `@Environment(\.accessibilityReduceMotion)` itself, same
//     as `RPGSceneView` already does for combat animations.
//   - Reduce Motion targets movement that plays out on its own (offsets,
//     rises, parallax) — gate those. A tiny press-down squish synchronous
//     with the touch itself (see `PixelButtonStyle`) isn't in that category
//     and doesn't need gating, matching how system buttons behave.
//   - Never gate or disable a logging control (set checkboxes, reps/weight
//     fields, Add Set) behind an animation's duration — e.g. the rest timer
//     banner in `ExerciseLoggingView` runs alongside logging, never over it.
//
// Haptics — use `.sensoryFeedback(_:trigger:)`, never a raw
// `UIImpactFeedbackGenerator`:
//   - Frequent, low-stakes actions (set completion) get `.selection` — a
//     light tick that won't fatigue across a whole workout.
//   - Celebratory, rare moments (quest complete, level up, achievement
//     unlock) layer feedback: a base `.success` for "it happened," plus
//     `.impact(weight:)` at increasing weight for bigger wins, so more
//     happening produces more feedback rather than one flat buzz regardless
//     of magnitude. See `QuestCompletionView`.
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

    /// Lightweight staggered fade+slide entrance for a row in a freshly-earned
    /// list (XP rewards, level-ups, achievement unlocks) so items cascade in
    /// rather than all popping in at once. Skips the animation (appears
    /// instantly) under Reduce Motion.
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearanceModifier(index: index))
    }
}

private struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}
