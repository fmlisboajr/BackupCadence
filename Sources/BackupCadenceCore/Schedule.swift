import Foundation

extension Calendar {
    func minuteOfDay(_ date: Date) -> Int {
        component(.hour, from: date) * 60 + component(.minute, from: date)
    }
}

/// Occurrences of the scheduled times on the days around `anchor` (±8 days), sorted ascending.
private func occurrences(_ times: [ScheduledTime], around anchor: Date, calendar: Calendar) -> [Date] {
    let startOfAnchor = calendar.startOfDay(for: anchor)
    var result: [Date] = []
    for offset in -8...8 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: startOfAnchor) else { continue }
        let weekday = calendar.component(.weekday, from: day)
        for t in times where t.weekdays.contains(weekday) {
            if let d = calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: day) {
                result.append(d)
            }
        }
    }
    return result.sorted()
}

public func mostRecentOccurrence(_ times: [ScheduledTime], onOrBefore now: Date, calendar: Calendar = .current) -> Date? {
    occurrences(times, around: now, calendar: calendar).last { $0 <= now }
}

public func nextOccurrence(_ times: [ScheduledTime], after now: Date, calendar: Calendar = .current) -> Date? {
    occurrences(times, around: now, calendar: calendar).first { $0 > now }
}

/// Moves `date` to the end of the forbidden window if it falls inside it.
private func pushOutOfWindow(_ date: Date, window: TimeWindow?, calendar: Calendar) -> Date {
    guard let window, window.contains(minuteOfDay: calendar.minuteOfDay(date)) else { return date }
    let comps = DateComponents(hour: window.endMinute / 60, minute: window.endMinute % 60, second: 0)
    return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime) ?? date
}

/// Predicted time of the next scheduled backup (best effort: ignores battery and idle state).
public func predictNextBackup(
    now: Date,
    config: BackupConfig,
    lastBackup: Date?,
    pausedUntil: Date?,
    calendar: Calendar = .current
) -> Date? {
    let config = config.sanitized
    guard config.enabled else { return nil }
    var candidate: Date
    switch config.mode {
    case .interval:
        candidate = lastBackup.map { $0.addingTimeInterval(Double(config.intervalHours) * 3600) } ?? now
    case .times:
        if lastBackup == nil {
            candidate = now
        } else if let occ = mostRecentOccurrence(config.times, onOrBefore: now, calendar: calendar),
                  let last = lastBackup, occ > last {
            candidate = now
        } else if let next = nextOccurrence(config.times, after: now, calendar: calendar) {
            candidate = next
        } else {
            return nil
        }
    case .idle:
        candidate = lastBackup.map { $0.addingTimeInterval(Double(config.idleMinHoursBetween) * 3600) } ?? now
    }
    candidate = max(candidate, now)
    if let pausedUntil { candidate = max(candidate, pausedUntil) }
    return pushOutOfWindow(candidate, window: config.forbiddenWindow, calendar: calendar)
}
