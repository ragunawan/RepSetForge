import SwiftUI
import XCTest
@testable import RepSetForge

final class DesignTokenContrastTests: XCTestCase {
  func testRequiredTextContrastPairsPassInLightAndDark() {
    let textPairs: [(String, Color, Color)] = [
      ("primary on surface", DesignTokens.ColorToken.textPrimary, DesignTokens.ColorToken.surface),
      ("primary on raised", DesignTokens.ColorToken.textPrimary, DesignTokens.ColorToken.surfaceRaised),
      ("primary on input", DesignTokens.ColorToken.textPrimary, DesignTokens.ColorToken.surfaceInput),
      ("secondary on surface", DesignTokens.ColorToken.textSecondary, DesignTokens.ColorToken.surface),
      ("secondary on raised", DesignTokens.ColorToken.textSecondary, DesignTokens.ColorToken.surfaceRaised),
      ("secondary on input", DesignTokens.ColorToken.textSecondary, DesignTokens.ColorToken.surfaceInput),
      ("on signal", DesignTokens.ColorToken.onSignal, DesignTokens.ColorToken.signal),
      ("warning on surface", DesignTokens.ColorToken.warning, DesignTokens.ColorToken.surface),
      ("destructive on raised", DesignTokens.ColorToken.destructive, DesignTokens.ColorToken.surfaceRaised)
    ]

    for style in [UIUserInterfaceStyle.light, .dark] {
      for pair in textPairs {
        let ratio = contrastRatio(foreground: pair.1, background: pair.2, style: style)
        XCTAssertGreaterThanOrEqual(
          ratio,
          4.5,
          "\(pair.0) in \(style == .light ? "light" : "dark") mode contrast was \(ratio)"
        )
      }
    }
  }

  func testLightModeSignalUsesAccessibleGreen() {
    let signal = rgba(DesignTokens.ColorToken.signal, style: .light)
    XCTAssertEqual(signal.red, 31, accuracy: 1)
    XCTAssertEqual(signal.green, 169, accuracy: 1)
    XCTAssertEqual(signal.blue, 104, accuracy: 1)
  }

  private func contrastRatio(foreground: Color, background: Color, style: UIUserInterfaceStyle) -> Double {
    let foregroundLuminosity = relativeLuminosity(rgba(foreground, style: style))
    let backgroundLuminosity = relativeLuminosity(rgba(background, style: style))
    let lighter = max(foregroundLuminosity, backgroundLuminosity)
    let darker = min(foregroundLuminosity, backgroundLuminosity)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private func rgba(_ color: Color, style: UIUserInterfaceStyle) -> RGBA {
    let traits = UITraitCollection(userInterfaceStyle: style)
    let resolved = UIColor(color).resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return RGBA(red: Double(red * 255), green: Double(green * 255), blue: Double(blue * 255))
  }

  private func relativeLuminosity(_ color: RGBA) -> Double {
    let red = linearized(color.red / 255)
    let green = linearized(color.green / 255)
    let blue = linearized(color.blue / 255)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue
  }

  private func linearized(_ component: Double) -> Double {
    component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
  }

  private struct RGBA {
    let red: Double
    let green: Double
    let blue: Double
  }
}
