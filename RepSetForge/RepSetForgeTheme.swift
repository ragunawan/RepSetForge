import SwiftUI
import UIKit

/// Design tokens translated from `Docs/repsetforge-hifi.html`'s CSS custom
/// properties ("Direction A", dark-primary, monospaced-throughout). The
/// mockup references a `gymchalk-tokens.json` file that was never provided;
/// these values are read directly off the mockup's `:root` / `.light` blocks —
/// reconcile against the real file if it ever shows up (see TODO.md).
///
/// Every color below is a *dynamic* `Color` (backed by `UIColor(dynamicProvider:)`)
/// that resolves dark vs. light per the environment's trait collection —
/// this is what makes `.preferredColorScheme(theme.colorScheme)` at
/// `ContentView`'s root (dev spec §6, Settings' theme picker) actually
/// repaint every screen, since every call site just references
/// `RepSetForgeTheme.Colors.X` with no light/dark branching of its own.
/// (An earlier pass added a separate, never-referenced `LightColors` enum
/// for this — every view kept using the dark hex values regardless of
/// `colorScheme`, so picking "Light" only flipped system chrome while every
/// custom-drawn surface/text color stayed dark. Fixed here instead of at
/// each of the ~20 call sites.)
enum RepSetForgeTheme {
    enum Colors {
        static let surface = Color.dynamic(dark: 0x0D0F12, light: 0xF7F8FA)
        static let surfaceRaised = Color.dynamic(dark: 0x16191E, light: 0xFFFFFF)
        static let surfaceInput = Color.dynamic(dark: 0x1D2127, light: 0xEEF0F4)
        static let hairline = Color.dynamic(dark: 0x262B33, light: 0xE2E5EA)
        static let textPrimary = Color.dynamic(dark: 0xF2F4F7, light: 0x111418)
        static let textSecondary = Color.dynamic(dark: 0x8B93A1, light: 0x5C6572)
        static let textTertiary = Color.dynamic(dark: 0x5A6270, light: 0x98A0AC)

        /// Completion/actions/progression — never reuse for anything else.
        static let signal = Color.dynamic(dark: 0x30E585, light: 0x1FA968)
        static let signalDim = Color.dynamic(dark: 0x30E585, darkOpacity: 0.14, light: 0x1FA968, lightOpacity: 0.12)
        /// PRs only.
        static let pr = Color.dynamic(dark: 0xF5C542, light: 0xB8860B)
        static let prDim = Color.dynamic(dark: 0xF5C542, darkOpacity: 0.14, light: 0xB8860B, lightOpacity: 0.12)
        // The mockup's light-mode CSS block doesn't define separate warn/
        // destructive values, so these stay mode-invariant — #FF7A59 / #FF5D5D
        // both still clear 4.5:1 against the light surface (0xF7F8FA) at the
        // sizes/weights they're used at in this app (bold, ≥12pt).
        static let warn = Color(hex: 0xFF7A59)
        static let destructive = Color(hex: 0xFF5D5D)
    }

    enum Radius {
        static let card: CGFloat = 10
        static let input: CGFloat = 8
        static let pill: CGFloat = 22
    }

    enum Typography {
        /// The mockup uses one monospaced voice for both labels and numerals
        /// ("v1.5: monospaced type throughout").
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A `Color` that resolves to `dark`/`light` (with independent alphas,
    /// since some tokens use a different dim-opacity per mode) based on the
    /// current trait collection rather than a fixed value picked at
    /// declaration time.
    static func dynamic(dark: UInt32, darkOpacity: Double = 1, light: UInt32, lightOpacity: Double = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkOpacity)
                : UIColor(hex: light, alpha: lightOpacity)
        })
    }
}

fileprivate extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
