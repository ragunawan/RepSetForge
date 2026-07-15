import SwiftUI

/// Design tokens translated from `Docs/repsetforge-hifi.html`'s CSS custom
/// properties ("Direction A", dark-primary, monospaced-throughout). The
/// mockup references a `gymchalk-tokens.json` file that was never provided;
/// these values are read directly off the mockup's `:root` / `.light` blocks —
/// reconcile against the real file if it ever shows up (see TODO.md).
enum RepSetForgeTheme {
    enum Colors {
        // Dark (default)
        static let surface = Color(hex: 0x0D0F12)
        static let surfaceRaised = Color(hex: 0x16191E)
        static let surfaceInput = Color(hex: 0x1D2127)
        static let hairline = Color(hex: 0x262B33)
        static let textPrimary = Color(hex: 0xF2F4F7)
        static let textSecondary = Color(hex: 0x8B93A1)
        static let textTertiary = Color(hex: 0x5A6270)

        /// Completion/actions/progression — never reuse for anything else.
        static let signal = Color(hex: 0x30E585)
        static let signalDim = Color(hex: 0x30E585).opacity(0.14)
        /// PRs only.
        static let pr = Color(hex: 0xF5C542)
        static let prDim = Color(hex: 0xF5C542).opacity(0.14)
        static let warn = Color(hex: 0xFF7A59)
        static let destructive = Color(hex: 0xFF5D5D)
    }

    enum LightColors {
        static let surface = Color(hex: 0xF7F8FA)
        static let surfaceRaised = Color(hex: 0xFFFFFF)
        static let surfaceInput = Color(hex: 0xEEF0F4)
        static let hairline = Color(hex: 0xE2E5EA)
        static let textPrimary = Color(hex: 0x111418)
        static let textSecondary = Color(hex: 0x5C6572)
        static let textTertiary = Color(hex: 0x98A0AC)

        static let signal = Color(hex: 0x1FA968)
        static let signalDim = Color(hex: 0x1FA968).opacity(0.12)
        static let pr = Color(hex: 0xB8860B)
        static let prDim = Color(hex: 0xB8860B).opacity(0.12)
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

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
