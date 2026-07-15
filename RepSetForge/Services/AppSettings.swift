import Foundation
import SwiftUI

/// `@AppStorage` key constants — centralized so `SettingsView` and the
/// screens that read these values (`ExerciseFocusView`'s default rest,
/// `SetRowView`'s RPE visibility, the app-root theme) can't drift apart
/// through a typo'd string literal.
enum AppSettingsKeys {
    static let weightUnit = "settings.weightUnit"
    static let defaultRestSeconds = "settings.defaultRestSeconds"
    static let showRPE = "settings.showRPE"
    static let theme = "settings.theme"
}

/// Stored but not yet threaded through every kg display in the app — see
/// TODO.md. The setting exists so it's ready once that conversion work happens.
enum WeightUnitPreference: String, CaseIterable, Identifiable, Hashable {
    case kilograms = "kg"
    case pounds = "lb"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum ThemePreference: String, CaseIterable, Identifiable, Hashable {
    case light, dark, system

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
