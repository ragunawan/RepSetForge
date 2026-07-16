import Foundation

enum StrengthMath {
  static func estimatedOneRepMax(weightKg: Decimal?, reps: Int?) -> Decimal? {
    guard let weightKg, let reps, reps > 0, reps <= 12 else { return nil }
    return weightKg * (1 + Decimal(reps) / 30)
  }
}
