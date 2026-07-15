import Testing
import Foundation
@testable import RepSetForge

struct RestTimerManagerTests {
    @Test func startSetsRemainingToTheFullDuration() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 90, now: start)

        #expect(manager.isResting)
        #expect(manager.remaining(now: start) == 90)
    }

    @Test func remainingCountsDownAndGoesNegativeInOvertime() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 90, now: start)

        #expect(manager.remaining(now: start.addingTimeInterval(30)) == 60)
        #expect(manager.remaining(now: start.addingTimeInterval(100)) == -10)
    }

    @Test func extendPushesBackTheEndDate() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 60, now: start)
        manager.extend(by: 30, now: start)

        #expect(manager.remaining(now: start) == 90)
    }

    @Test func skipEndsTheRestAndRecordsTheInterval() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 90, now: start)
        manager.skip(now: start.addingTimeInterval(20))

        #expect(!manager.isResting)
        #expect(manager.completedRestIntervals.count == 1)
        #expect(manager.completedRestIntervals[0].duration == 20)
    }

    @Test func cumulativeRestSumsCompletedIntervalsPlusTheRunningOne() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 90, now: start)
        manager.skip(now: start.addingTimeInterval(30))

        manager.start(duration: 90, now: start.addingTimeInterval(100))
        let cumulative = manager.cumulativeRest(now: start.addingTimeInterval(140))

        #expect(cumulative == 70)
    }

    @Test func startWhileAlreadyRestingFinishesThePreviousIntervalFirst() {
        let manager = RestTimerManager()
        let start = Date(timeIntervalSince1970: 1_000_000)
        manager.start(duration: 90, now: start)
        manager.start(duration: 60, now: start.addingTimeInterval(10))

        #expect(manager.completedRestIntervals.count == 1)
        #expect(manager.completedRestIntervals[0].duration == 10)
        #expect(manager.remaining(now: start.addingTimeInterval(10)) == 60)
    }
}
