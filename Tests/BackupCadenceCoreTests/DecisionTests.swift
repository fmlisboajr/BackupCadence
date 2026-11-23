import Testing
import Foundation
@testable import BackupCadenceCore

@Suite struct DecisionTests {
    // MARK: interval
    @Test func intervalDue() {
        let c = config(.interval) { $0.intervalHours = 4 }
        #expect(decideNow(date(23, 12), c, last: date(23, 8)) == .start)
    }
    @Test func intervalNotDue() {
        let c = config(.interval) { $0.intervalHours = 4 }
        #expect(decideNow(date(23, 11), c, last: date(23, 8)) == .skip(.notDue(next: date(23, 12))))
    }
    @Test func firstRunWithoutPreviousBackupStarts() {
        for mode in [ScheduleMode.interval, .times] {
            #expect(decideNow(date(23, 12), config(mode), last: nil) == .start)
        }
        #expect(decideNow(date(23, 12), config(.idle), last: nil, idle: 3600) == .start)
    }

    // MARK: times
    @Test func timesDueAfterScheduledSlot() {
        let c = config(.times) { $0.times = [ScheduledTime(weekdays: [2], hour: 2)] } // Monday 02:00
        #expect(decideNow(date(23, 3), c, last: date(22, 20)) == .start)
    }
    @Test func timesAlreadyDoneForSlot() {
        let c = config(.times) { $0.times = [ScheduledTime(weekdays: [2], hour: 2)] }
        #expect(decideNow(date(23, 3), c, last: date(23, 2, 5)) == .skip(.notDue(next: date(30, 2))))
    }
    @Test func timesWrongWeekday() {
        // Only Saturday 12:00; 2026-11-23 is Monday, last Saturday's slot was done.
        let c = config(.times) { $0.times = [ScheduledTime(weekdays: [7], hour: 12)] }
        #expect(decideNow(date(23, 13), c, last: date(21, 12, 5)) == .skip(.notDue(next: date(28, 12))))
    }
    @Test func timesCatchUpAfterMissedSlot() {
        let c = config(.times) { $0.times = [ScheduledTime(weekdays: [2], hour: 2)] }
        #expect(decideNow(date(23, 9), c, last: date(20, 2)) == .start)
    }

    // MARK: idle
    @Test func idleLongEnough() {
        let c = config(.idle) { $0.idleMinutes = 10; $0.idleMinHoursBetween = 4 }
        #expect(decideNow(date(23, 12), c, last: date(23, 6), idle: 601) == .start)
    }
    @Test func idleNotLongEnough() {
        let c = config(.idle) { $0.idleMinutes = 10 }
        #expect(decideNow(date(23, 12), c, last: date(23, 6), idle: 120) == .skip(.notIdle(idleSeconds: 120, neededSeconds: 600)))
    }
    @Test func idleButTooSoonSinceLastBackup() {
        let c = config(.idle) { $0.idleMinutes = 10; $0.idleMinHoursBetween = 4 }
        #expect(decideNow(date(23, 12), c, last: date(23, 10), idle: 3600) == .skip(.notDue(next: date(23, 14))))
    }

    // MARK: constraints
    @Test func batteryBlocks() {
        #expect(decideNow(date(23, 12), config(.interval), last: nil, battery: true) == .skip(.onBattery))
    }
    @Test func batteryAllowedWhenOptionOff() {
        let c = config(.interval) { $0.skipOnBattery = false }
        #expect(decideNow(date(23, 12), c, last: nil, battery: true) == .start)
    }
    @Test func forbiddenWindowSameDay() {
        let c = config(.interval) { $0.forbiddenWindow = TimeWindow(startMinute: 9 * 60, endMinute: 17 * 60) }
        #expect(decideNow(date(23, 10), c, last: nil) == .skip(.forbiddenWindow))
        #expect(decideNow(date(23, 17), c, last: nil) == .start)
        #expect(decideNow(date(23, 8, 59), c, last: nil) == .start)
    }
    @Test func forbiddenWindowAcrossMidnight() {
        let c = config(.interval) { $0.forbiddenWindow = TimeWindow(startMinute: 22 * 60, endMinute: 6 * 60) }
        #expect(decideNow(date(23, 23), c, last: nil) == .skip(.forbiddenWindow))
        #expect(decideNow(date(24, 2), c, last: nil) == .skip(.forbiddenWindow))
        #expect(decideNow(date(24, 6), c, last: nil) == .start)
        #expect(decideNow(date(23, 21, 59), c, last: nil) == .start)
    }
    @Test func alreadyRunning() {
        #expect(decideNow(date(23, 12), config(.interval), last: nil, running: true) == .skip(.alreadyRunning))
    }
    @Test func paused() {
        #expect(decideNow(date(23, 12), config(.interval), last: nil, paused: date(23, 13)) == .skip(.paused(until: date(23, 13))))
    }
    @Test func pauseExpired() {
        #expect(decideNow(date(23, 12), config(.interval), last: nil, paused: date(23, 11)) == .start)
    }
    @Test func disabled() {
        var c = config(.interval); c.enabled = false
        #expect(decideNow(date(23, 12), c, last: nil) == .skip(.disabled))
    }

    // MARK: next backup prediction
    @Test func predictInterval() {
        let c = config(.interval) { $0.intervalHours = 6 }
        #expect(predictNextBackup(now: date(23, 12), config: c, lastBackup: date(23, 10), pausedUntil: nil, calendar: utc) == date(23, 16))
    }
    @Test func predictOverdueIsNow() {
        let c = config(.interval) { $0.intervalHours = 1 }
        #expect(predictNextBackup(now: date(23, 12), config: c, lastBackup: date(22, 10), pausedUntil: nil, calendar: utc) == date(23, 12))
    }
    @Test func predictTimes() {
        let c = config(.times) { $0.times = [ScheduledTime(weekdays: [2, 3, 4, 5, 6], hour: 2), ScheduledTime(weekdays: [7], hour: 12)] }
        // Friday 27th after 02:00 slot done -> next is Saturday 28th 12:00.
        #expect(predictNextBackup(now: date(27, 10), config: c, lastBackup: date(27, 2, 3), pausedUntil: nil, calendar: utc) == date(28, 12))
        // Saturday 12:00 done -> next Monday 30th 02:00.
        #expect(predictNextBackup(now: date(28, 13), config: c, lastBackup: date(28, 12, 1), pausedUntil: nil, calendar: utc) == date(30, 2))
    }
    @Test func predictIdleUsesMinGap() {
        let c = config(.idle) { $0.idleMinHoursBetween = 8 }
        #expect(predictNextBackup(now: date(23, 12), config: c, lastBackup: date(23, 10), pausedUntil: nil, calendar: utc) == date(23, 18))
    }
    @Test func predictPushedByForbiddenWindow() {
        let c = config(.interval) { $0.intervalHours = 4; $0.forbiddenWindow = TimeWindow(startMinute: 22 * 60, endMinute: 6 * 60) }
        // due 23:00 (inside window) -> 06:00 next day
        #expect(predictNextBackup(now: date(23, 20), config: c, lastBackup: date(23, 19), pausedUntil: nil, calendar: utc) == date(24, 6))
    }
    @Test func predictPushedByPause() {
        let c = config(.interval) { $0.intervalHours = 1 }
        #expect(predictNextBackup(now: date(23, 12), config: c, lastBackup: date(23, 11), pausedUntil: date(24, 0), calendar: utc) == date(24, 0))
    }
    @Test func predictNilWhenDisabled() {
        var c = config(.interval); c.enabled = false
        #expect(predictNextBackup(now: date(23, 12), config: c, lastBackup: nil, pausedUntil: nil, calendar: utc) == nil)
    }
}
