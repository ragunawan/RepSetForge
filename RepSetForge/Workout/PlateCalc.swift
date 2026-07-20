import Foundation
import SwiftUI

/// §3 contract #2: long-press weight → plate calculator popover.
/// Pure greedy per-side breakdown from bar weight + available plates.
enum PlateCalc {
    struct Breakdown: Equatable {
        /// (plate kg, count) per side, heaviest first.
        var perSide: [(plateKg: Double, count: Int)]
        /// Weight that cannot be built from the available plates (per side).
        var remainderKg: Double
        var barKg: Double

        static func == (l: Breakdown, r: Breakdown) -> Bool {
            l.remainderKg == r.remainderKg && l.barKg == r.barKg &&
            l.perSide.elementsEqual(r.perSide, by: ==)
        }
    }

    /// nil when the target is below the bar itself.
    static func breakdown(targetKg: Double, barKg: Double, plates: [Double]) -> Breakdown? {
        guard targetKg >= barKg else { return nil }
        var side = (targetKg - barKg) / 2
        var out: [(Double, Int)] = []
        for p in plates.filter({ $0 > 0 }).sorted(by: >) {
            let n = Int((side / p).rounded(.down) + 1e-9)
            if n > 0 {
                out.append((p, n))
                side -= Double(n) * p
            }
        }
        return Breakdown(perSide: out, remainderKg: (side * 100).rounded() / 100, barKg: barKg)
    }
}

/// Popover content: BAR + per-side plate list, loadable/short note.
struct PlateCalcView: View {
    let targetKg: Double
    let barKg: Double
    let plates: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: DT.Spacing.s8) {
            Text("PLATES · \(fmt(targetKg)) KG")
                .font(DT.Type.eyebrow)
                .foregroundStyle(DT.Colors.textTertiary)
            if let b = PlateCalc.breakdown(targetKg: targetKg, barKg: barKg, plates: plates) {
                HStack {
                    Text("Bar").foregroundStyle(DT.Colors.textSecondary)
                    Spacer()
                    Text("\(fmt(b.barKg)) kg").monospacedDigit()
                }
                if b.perSide.isEmpty {
                    Text("No plates needed")
                        .foregroundStyle(DT.Colors.textSecondary)
                } else {
                    ForEach(b.perSide, id: \.plateKg) { row in
                        HStack {
                            Text("\(fmt(row.plateKg)) kg × \(row.count)")
                                .monospacedDigit()
                            Spacer()
                            Text("per side")
                                .font(DT.Type.eyebrow)
                                .foregroundStyle(DT.Colors.textTertiary)
                        }
                    }
                }
                if b.remainderKg > 0 {
                    Text("−\(fmt(b.remainderKg * 2)) kg short (no matching plates)")
                        .font(DT.Type.secondary)
                        .foregroundStyle(DT.Colors.pr)
                }
            } else {
                Text("Below bar weight (\(fmt(barKg)) kg)")
                    .foregroundStyle(DT.Colors.textSecondary)
            }
        }
        .font(DT.Type.secondary)
        .foregroundStyle(DT.Colors.textPrimary)
        .monospacedDigit()
        .padding(DT.Spacing.s16)
        .presentationCompactAdaptation(.popover)
    }

    private func fmt(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)))
    }
}
