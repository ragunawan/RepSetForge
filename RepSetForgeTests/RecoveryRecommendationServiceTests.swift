import XCTest
@testable import RepSetForge

final class RecoveryRecommendationServiceTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday, fixed regardless of test-runner locale
        return calendar
    }

    private func now() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 18 // a Wednesday, safely mid-week
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func completedQuest(daysAgo: Int, xp: Int = 0, volume: Double = 0) -> Quest {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now())!
        let quest = Quest(name: "Quest", date: date, status: .completed)
        quest.completedDate = date
        quest.totalXP = xp
        if volume > 0 {
            let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
            let reps = 10
            let weight = volume / Double(reps)
            exercise.sets.append(ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true))
            quest.exercises.append(exercise)
        }
        return quest
    }

    func testNoHistoryYieldsAllClear() {
        XCTAssertEqual(RecoveryRecommendationService.recommendation(from: [], calendar: calendar, now: now()), .allClear)
    }

    func testSevenDayStreakRecommendsRestDay() {
        let quests = (0..<7).map { completedQuest(daysAgo: $0) }
        let recommendation = RecoveryRecommendationService.recommendation(from: quests, calendar: calendar, now: now())
        XCTAssertEqual(recommendation, .restDay(streakDays: 7))
    }

    func testShortStreakDoesNotRecommendRestDay() {
        let quests = (0..<3).map { completedQuest(daysAgo: $0) }
        let recommendation = RecoveryRecommendationService.recommendation(from: quests, calendar: calendar, now: now())
        XCTAssertNotEqual(recommendation, .restDay(streakDays: 3))
    }

    func testRisingVolumeAcrossFourWeeksRecommendsDeload() {
        // Weeks 3,2,1,0 back from now, each with strictly increasing volume, one quest each (no daily streak).
        let quests = [
            completedQuest(daysAgo: 21, volume: 1000),
            completedQuest(daysAgo: 14, volume: 2000),
            completedQuest(daysAgo: 7, volume: 3000),
            completedQuest(daysAgo: 0, volume: 4000),
        ]
        let recommendation = RecoveryRecommendationService.recommendation(from: quests, calendar: calendar, now: now())
        XCTAssertEqual(recommendation, .deloadWeek(weeks: 3))
    }

    func testFlatOrDecliningVolumeDoesNotRecommendDeload() {
        let quests = [
            completedQuest(daysAgo: 21, volume: 3000),
            completedQuest(daysAgo: 14, volume: 3000),
            completedQuest(daysAgo: 7, volume: 2000),
            completedQuest(daysAgo: 0, volume: 4000),
        ]
        let recommendation = RecoveryRecommendationService.recommendation(from: quests, calendar: calendar, now: now())
        XCTAssertEqual(recommendation, .allClear)
    }

    func testRestDayTakesPriorityOverDeloadWhenBothApply() {
        var quests = (0..<7).map { completedQuest(daysAgo: $0, volume: 1000) }
        quests.append(completedQuest(daysAgo: 14, volume: 500))
        quests.append(completedQuest(daysAgo: 21, volume: 250))
        let recommendation = RecoveryRecommendationService.recommendation(from: quests, calendar: calendar, now: now())
        if case .restDay = recommendation {
            // expected
        } else {
            XCTFail("Expected restDay to take priority, got \(recommendation)")
        }
    }

    func testIgnoresIncompleteQuestsForStreak() {
        let planned = Quest(name: "Planned", status: .planned)
        let recommendation = RecoveryRecommendationService.recommendation(from: [planned], calendar: calendar, now: now())
        XCTAssertEqual(recommendation, .allClear)
    }
}
