import Foundation

public enum SkipReason: Equatable, Sendable {
    case disabled
    case paused(until: Date)
    case alreadyRunning
    case onBattery
    case forbiddenWindow
    case notDue(next: Date?)
    case notIdle(idleSeconds: Int, neededSeconds: Int)

    public var text: String {
        switch self {
        case .disabled: return "scheduling is turned off"
        case .paused(let until): return "paused until \(until.formatted(date: .abbreviated, time: .shortened))"
        case .alreadyRunning: return "a backup is already running"
        case .onBattery: return "running on battery"
        case .forbiddenWindow: return "inside the forbidden time window"
        case .notDue(let next):
            if let next { return "not due yet (next \(next.formatted(date: .abbreviated, time: .shortened)))" }
            return "not due yet"
        case .notIdle(let idle, let needed): return "Mac not idle long enough (\(idle)s of \(needed)s)"
        }
    }
}

public enum Decision: Equatable, Sendable {
    case start
    case skip(SkipReason)

    public var summary: String {
        switch self {
        case .start: return "start"
        case .skip(let r): return "skip: \(r.text)"
        }
    }
}

/// Pure rule: should a scheduled backup start right now?
public func decide(
    now: Date,
    config: BackupConfig,
    lastBackup: Date?,
    onBattery: Bool,
    idleSeconds: TimeInterval,
    isRunning: Bool,
    pausedUntil: Date?,
    calendar: Calendar = .current
) -> Decision {
    let config = config.sanitized
    if !config.enabled { return .skip(.disabled) }
    if let pausedUntil, pausedUntil > now { return .skip(.paused(until: pausedUntil)) }
    if isRunning { return .skip(.alreadyRunning) }
    if config.skipOnBattery && onBattery { return .skip(.onBattery) }
    if let w = config.forbiddenWindow, w.contains(minuteOfDay: calendar.minuteOfDay(now)) {
        return .skip(.forbiddenWindow)
    }

    switch config.mode {
    case .interval:
        guard let last = lastBackup else { return .start }
        let due = last.addingTimeInterval(Double(config.intervalHours) * 3600)
        return now >= due ? .start : .skip(.notDue(next: due))
    case .times:
        guard let last = lastBackup else { return .start }
        if let occ = mostRecentOccurrence(config.times, onOrBefore: now, calendar: calendar), occ > last {
            return .start
        }
        let next = nextOccurrence(config.times, after: now, calendar: calendar)
        return .skip(.notDue(next: next))
    case .idle:
        let needed = config.idleMinutes * 60
        if let last = lastBackup {
            let due = last.addingTimeInterval(Double(config.idleMinHoursBetween) * 3600)
            if now < due { return .skip(.notDue(next: due)) }
        }
        if Int(idleSeconds) < needed { return .skip(.notIdle(idleSeconds: Int(idleSeconds), neededSeconds: needed)) }
        return .start
    }
}
