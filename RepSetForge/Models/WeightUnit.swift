import Foundation

/// Unit a weight value is expressed in. Each ExerciseSet (and weight-based
/// PersonalRecord) remembers its own unit rather than assuming a single
/// global unit, so changing the app-wide preference later never reinterprets
/// or "confuses" a weight that was already logged — historical entries keep
/// displaying exactly as they were recorded.
enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case pounds = "lb"
    case kilograms = "kg"

    var id: String { rawValue }

    var displayName: String {
        self == .pounds ? "Pounds (lb)" : "Kilograms (kg)"
    }

    var abbreviation: String { rawValue }

    private static let poundsPerKilogram = 2.2046226218

    /// Converts a value expressed in `self` into the given unit.
    func convert(_ value: Double, to other: WeightUnit) -> Double {
        guard self != other else { return value }
        return self == .pounds ? value / Self.poundsPerKilogram : value * Self.poundsPerKilogram
    }

    func formatted(_ value: Double) -> String {
        String(format: "%.1f %@", value, abbreviation)
    }
}
