import XCTest
@testable import RepSetForge

final class CSVCodecTests: XCTestCase {
    func testRoundTrip() {
        let rows = [
            CSVCodec.Row(date: Date(timeIntervalSince1970: 1_700_000_000),
                         exercise: "Bench Press", setType: .working,
                         weightKg: 102.5, reps: 8, rpe: 8),
            CSVCodec.Row(date: Date(timeIntervalSince1970: 1_700_000_100),
                         exercise: "Row, Barbell \"heavy\"", setType: .warmup,
                         weightKg: 60, reps: 10, rpe: nil),
        ]
        let csv = CSVCodec.export(rows: rows)
        XCTAssertTrue(csv.hasPrefix(CSVCodec.header))
        let (imported, skipped) = CSVCodec.importCSV(csv)
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(imported, rows)
    }

    func testImportSkipsMalformedKeepsGood() {
        let csv = """
        date,exercise,set_type,weight_kg,reps,rpe
        2026-07-01T10:00:00Z,Squat,working,140,5,8
        not-a-date,Squat,working,140,5,8
        2026-07-01T10:05:00Z,,working,140,5,8
        2026-07-01T10:10:00Z,Squat,notatype,140,5,8
        2026-07-01T10:15:00Z,Deadlift,working,180,3,
        """
        let (rows, skipped) = CSVCodec.importCSV(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(skipped, 3)
        XCTAssertNil(rows[1].rpe)
        XCTAssertEqual(rows[1].exercise, "Deadlift")
    }
}
