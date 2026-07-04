import XCTest
@testable import RepSetForge

final class TrainingChartsServiceTests: XCTestCase {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday, fixed regardless of test-runner locale
        return calendar
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return utcCalendar.date(from: components)!
    }

    private func completedQuest(daysAgoFrom now: Date, days: Int, xp: Int, exercises: [Exercise] = []) -> Quest {
        let completedDate = utcCalendar.date(byAdding: .day, value: -days, to: now)!
        let quest = Quest(name: "Quest", date: completedDate, status: .completed)
        quest.completedDate = completedDate
        quest.totalXP = xp
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(reps: Int, weight: Double, unit: WeightUnit = .pounds) -> Exercise {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        let set = ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true, weightUnit: unit)
        exercise.sets.append(set)
        return exercise
    }

    func testEmptyHistoryYieldsZeroedStatsForEveryPeriod() {
        let now = date(year: 2026, month: 3, day: 15)
        let stats = TrainingChartsService.periodStats(from: [], period: .week, periodsCount: 4, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.count, 4)
        XCTAssertTrue(stats.allSatisfy { $0.totalXP == 0 && $0.totalVolume == 0 && $0.daysTrained == 0 })
    }

    func testReturnsRequestedNumberOfPeriodsOldestFirst() {
        let now = date(year: 2026, month: 3, day: 15)
        let stats = TrainingChartsService.periodStats(from: [], period: .week, periodsCount: 6, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.count, 6)
        for index in 1..<stats.count {
            XCTAssertLessThan(stats[index - 1].periodStart, stats[index].periodStart)
        }
    }

    func testXPIsSummedWithinTheSameWeek() {
        let now = date(year: 2026, month: 3, day: 18) // a Wednesday, safely mid-week
        let questA = completedQuest(daysAgoFrom: now, days: 0, xp: 100)
        let questB = completedQuest(daysAgoFrom: now, days: 1, xp: 50)
        let stats = TrainingChartsService.periodStats(from: [questA, questB], period: .week, periodsCount: 1, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.last?.totalXP, 150)
    }

    func testQuestsOutsideThePeriodWindowAreExcluded() {
        let now = date(year: 2026, month: 3, day: 15)
        let old = completedQuest(daysAgoFrom: now, days: 100, xp: 999)
        let stats = TrainingChartsService.periodStats(from: [old], period: .week, periodsCount: 2, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.reduce(0) { $0 + $1.totalXP }, 0)
    }

    func testVolumeNormalizesKilogramsToPounds() throws {
        let now = date(year: 2026, month: 3, day: 15)
        let kgExercise = exercise(reps: 10, weight: 100, unit: .kilograms)
        let quest = completedQuest(daysAgoFrom: now, days: 0, xp: 0, exercises: [kgExercise])
        let stats = TrainingChartsService.periodStats(from: [quest], period: .week, periodsCount: 1, calendar: utcCalendar, now: now)
        let expectedVolume = 10.0 * WeightUnit.kilograms.convert(100, to: .pounds)
        let actualVolume = try XCTUnwrap(stats.last?.totalVolume)
        XCTAssertEqual(actualVolume, expectedVolume, accuracy: 0.01)
    }

    func testVolumeOnlyCountsCompletedSets() {
        let now = date(year: 2026, month: 3, day: 15)
        let ex = Exercise(name: "Bench", primaryMuscle: .chest)
        ex.sets.append(ExerciseSet(setNumber: 1, reps: 10, weight: 100, completed: true))
        ex.sets.append(ExerciseSet(setNumber: 2, reps: 10, weight: 100, completed: false))
        let quest = completedQuest(daysAgoFrom: now, days: 0, xp: 0, exercises: [ex])
        let stats = TrainingChartsService.periodStats(from: [quest], period: .week, periodsCount: 1, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.last?.totalVolume, 1000)
    }

    func testDaysTrainedCountsDistinctCalendarDaysNotQuests() {
        let now = date(year: 2026, month: 3, day: 18) // a Wednesday, safely mid-week
        let questA = completedQuest(daysAgoFrom: now, days: 0, xp: 10)
        let questB = completedQuest(daysAgoFrom: now, days: 0, xp: 10) // same day, second quest
        let questC = completedQuest(daysAgoFrom: now, days: 1, xp: 10)
        let stats = TrainingChartsService.periodStats(from: [questA, questB, questC], period: .week, periodsCount: 1, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.last?.daysTrained, 2)
    }

    func testIgnoresIncompleteQuests() {
        let now = date(year: 2026, month: 3, day: 15)
        let planned = Quest(name: "Planned", status: .planned)
        let stats = TrainingChartsService.periodStats(from: [planned], period: .week, periodsCount: 1, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.last?.totalXP, 0)
    }

    func testMonthlyPeriodGroupsAcrossTheWholeMonth() {
        let now = date(year: 2026, month: 3, day: 28)
        let earlyMonth = completedQuest(daysAgoFrom: now, days: 25, xp: 100) // March 3rd
        let lateMonth = completedQuest(daysAgoFrom: now, days: 1, xp: 50) // March 27th
        let stats = TrainingChartsService.periodStats(from: [earlyMonth, lateMonth], period: .month, periodsCount: 1, calendar: utcCalendar, now: now)
        XCTAssertEqual(stats.last?.totalXP, 150)
    }
}
