import Foundation

/// §5 Home Body module math (ported from the prototype, resolved rules):
/// aggregation per period (daily points for W, weekly means for M, monthly
/// means for Y), BF% gap interpolation up to 14 days (nothing fabricated
/// beyond that), period paging with date-span labels, first→last deltas.
enum BodyChartMath {
    enum Range: String, CaseIterable {
        case week = "W", month = "M", year = "Y"
        var days: Int { self == .week ? 7 : self == .month ? 30 : 365 }
        var points: Int { self == .week ? 7 : self == .month ? 10 : 12 }
    }

    struct Sample: Equatable {
        var date: Date
        var value: Double
    }

    struct Series: Equatable {
        /// One slot per period point; nil = no data (render a gap).
        var points: [Double?]
        var delta: Double? {
            let vals = points.compactMap { $0 }
            guard let f = vals.first, let l = vals.last, vals.count > 1 else { return nil }
            return (l - f * 1).rounded(toPlaces: 1)
        }
        var latest: Double? { points.compactMap { $0 }.last }
    }

    /// Bucket samples into `range.points` slots covering the period ending
    /// `offset` periods before `now`, averaging samples per slot.
    static func aggregate(samples: [Sample], range: Range, offset: Int, now: Date,
                          calendar: Calendar = .current) -> Series {
        let periodEnd = calendar.date(byAdding: .day, value: -offset * range.days, to: now)!
        let periodStart = calendar.date(byAdding: .day, value: -range.days, to: periodEnd)!
        let slotLength = periodEnd.timeIntervalSince(periodStart) / Double(range.points)

        var buckets: [[Double]] = Array(repeating: [], count: range.points)
        for s in samples where s.date > periodStart && s.date <= periodEnd {
            let idx = min(range.points - 1,
                          Int(s.date.timeIntervalSince(periodStart) / slotLength))
            buckets[idx].append(s.value)
        }
        let pts = buckets.map { $0.isEmpty ? nil : ($0.reduce(0, +) / Double($0.count)).rounded(toPlaces: 1) }
        return Series(points: pts)
    }

    /// Interpolate interior gaps when the surrounding real samples are ≤
    /// `maxGapDays` apart; longer gaps stay nil (render nothing, never
    /// fabricate). Leading/trailing gaps are never filled.
    static func interpolateGaps(_ series: Series, slotDays: Double, maxGapDays: Double = 14) -> Series {
        var pts = series.points
        var lastIdx: Int?
        for i in pts.indices {
            guard pts[i] != nil else { continue }
            if let li = lastIdx, i - li > 1 {
                let gapDays = Double(i - li) * slotDays
                if gapDays <= maxGapDays {
                    let a = pts[li]!, b = pts[i]!
                    for j in (li + 1)..<i {
                        let t = Double(j - li) / Double(i - li)
                        pts[j] = (a + (b - a) * t).rounded(toPlaces: 1)
                    }
                }
            }
            lastIdx = i
        }
        return Series(points: pts)
    }

    /// `‹ JUL 6–12` style span label for a period `offset` back; year for Y.
    static func periodLabel(range: Range, offset: Int, now: Date,
                            calendar: Calendar = .current) -> String {
        let end = calendar.date(byAdding: .day, value: -offset * range.days, to: now)!
        let start = calendar.date(byAdding: .day, value: -(range.days - 1), to: end)!
        if range == .year {
            return String(calendar.component(.year, from: start))
        }
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(fmt)) – \(end.formatted(fmt))".uppercased()
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
