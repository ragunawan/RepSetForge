import XCTest
@testable import RepSetForge

final class BodyChartMathTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))! }

    func daysAgo(_ d: Int, _ v: Double) -> BodyChartMath.Sample {
        .init(date: cal.date(byAdding: .day, value: -d, to: now)!, value: v)
    }

    func testWeekAggregationBucketsDaily() {
        let samples = (0..<7).map { daysAgo($0, 80 + Double($0)) }
        let s = BodyChartMath.aggregate(samples: samples, range: .week, offset: 0, now: now, calendar: cal)
        XCTAssertEqual(s.points.count, 7)
        XCTAssertEqual(s.points.compactMap { $0 }.count, 7)
        XCTAssertEqual(s.latest, 80) // today's sample lands in the last slot
    }

    func testOffsetPagesIntoPreviousPeriod() {
        let old = daysAgo(10, 84)
        let cur = daysAgo(1, 82)
        let current = BodyChartMath.aggregate(samples: [old, cur], range: .week, offset: 0, now: now, calendar: cal)
        let previous = BodyChartMath.aggregate(samples: [old, cur], range: .week, offset: 1, now: now, calendar: cal)
        XCTAssertEqual(current.points.compactMap { $0 }, [82])
        XCTAssertEqual(previous.points.compactMap { $0 }, [84])
    }

    func testMultipleSamplesPerSlotAverage() {
        let s = BodyChartMath.aggregate(samples: [daysAgo(1, 80), daysAgo(1, 82)],
                                        range: .week, offset: 0, now: now, calendar: cal)
        XCTAssertEqual(s.points.compactMap { $0 }, [81.0])
    }

    func testInterpolationFillsShortGapsOnly() {
        // W range: slot = 1 day. Gap of 2 days → filled linearly.
        var series = BodyChartMath.Series(points: [17.0, nil, nil, 20.0, nil, nil, nil])
        series = BodyChartMath.interpolateGaps(series, slotDays: 1)
        XCTAssertEqual(series.points[1], 18.0)
        XCTAssertEqual(series.points[2], 19.0)
        XCTAssertNil(series.points[6], "trailing gap must not be fabricated")
    }

    func testInterpolationRefusesLongGaps() {
        // slotDays 7 (M-ish): a 3-slot gap = 21 days > 14 → stays nil.
        var series = BodyChartMath.Series(points: [17.0, nil, nil, 20.0])
        series = BodyChartMath.interpolateGaps(series, slotDays: 7)
        XCTAssertNil(series.points[1])
        XCTAssertNil(series.points[2])
    }

    func testDelta() {
        let s = BodyChartMath.Series(points: [82.0, nil, 81.2])
        XCTAssertEqual(s.delta, -0.8)
        XCTAssertNil(BodyChartMath.Series(points: [82.0, nil]).delta)
    }

    func testPeriodLabelYearShowsYear() {
        XCTAssertEqual(BodyChartMath.periodLabel(range: .year, offset: 0, now: now, calendar: cal), "2025")
    }
}
