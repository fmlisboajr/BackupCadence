import Foundation
@testable import BackupCadenceCore

/// UTC Gregorian calendar so tests do not depend on the machine's time zone.
let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// 2026-11-23 is a Monday.
func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

func config(_ mode: ScheduleMode, _ edit: (inout BackupConfig) -> Void = { _ in }) -> BackupConfig {
    var c = BackupConfig()
    c.enabled = true
    c.mode = mode
    edit(&c)
    return c
}

func decideNow(
    _ now: Date, _ cfg: BackupConfig, last: Date? = nil, battery: Bool = false,
    idle: TimeInterval = 0, running: Bool = false, paused: Date? = nil
) -> Decision {
    decide(now: now, config: cfg, lastBackup: last, onBattery: battery, idleSeconds: idle,
           isRunning: running, pausedUntil: paused, calendar: utc)
}

final class FakeClient: TimeMachineClient, @unchecked Sendable {
    var running = false
    var latest: Date?
    var started = 0
    var startedDestination: String??
    func status() throws -> TMStatus { TMStatus(isRunning: running) }
    func latestBackup() throws -> Date? { latest }
    func destinations() throws -> [TMDestination] { [] }
    func startBackup(destinationID: String?) throws { started += 1; startedDestination = .some(destinationID) }
}

struct FakeSignals: SystemSignals {
    var battery = false
    var idle: TimeInterval = 0
    func onBattery() -> Bool { battery }
    func idleSeconds() -> TimeInterval { idle }
}
