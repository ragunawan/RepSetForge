import SwiftUI

/// A tiny, standalone palette for the watch app — not shared with
/// `RepSetForgeTheme.swift`, which is built on `UIColor` (light/dark hex
/// pairs via `UIColor { traits in ... }`) and UIKit isn't available on
/// watchOS at all. Kept to just the couple of colors the watch views
/// actually use, in the same hex values as their phone-side equivalents,
/// rather than pulling in the phone's whole pixel-art panel/border/font
/// system for a companion app this simple.
extension Color {
    static let questGold = Color(red: 0xD9 / 255, green: 0xA9 / 255, blue: 0x31 / 255)
    static let questGreen = Color(red: 0x2E / 255, green: 0x8B / 255, blue: 0x57 / 255)
}
