import Foundation

enum StrengthMath {
    /// Epley e1RM `w × (1 + r/30)`, valid only for reps ≤ 12 (§2).
    /// reps == 1 returns the weight itself. Returns nil for reps > 12 or < 1.
    static func epleyE1RM(weightKg: Decimal, reps: Int) -> Decimal? {
        guard (1...12).contains(reps) else { return nil }
        guard reps > 1 else { return weightKg }
        return weightKg * (1 + Decimal(reps) / 30)
    }

    /// Lowercased, punctuation-stripped, whitespace-collapsed key (§2).
    static func canonicalNameKey(_ name: String) -> String {
        let lowered = name.lowercased()
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        return String(kept)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Set volume in kg (weight × reps); 0 when either is missing.
    static func volumeKg(weightKg: Decimal?, reps: Int?) -> Decimal {
        guard let w = weightKg, let r = reps else { return 0 }
        return w * Decimal(r)
    }
}
