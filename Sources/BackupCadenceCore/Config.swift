import Foundation

public enum ScheduleMode: String, Codable, CaseIterable, Sendable {
    case interval, times, idle
}

/// One entry of the "times" mode. `weekdays` uses `Calendar` numbering (1 = Sunday ... 7 = Saturday).
public struct ScheduledTime: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var weekdays: Set<Int>
    public var hour: Int
    public var minute: Int

    public init(id: UUID = UUID(), weekdays: Set<Int> = Set(1...7), hour: Int, minute: Int = 0) {
        self.id = id
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
    }
}

/// Minutes since midnight. May wrap across midnight (start > end).
public struct TimeWindow: Codable, Equatable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public func contains(minuteOfDay m: Int) -> Bool {
        if startMinute == endMinute { return false }
        if startMinute < endMinute { return m >= startMinute && m < endMinute }
        return m >= startMinute || m < endMinute
    }
}

public struct BackupConfig: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    public var mode: ScheduleMode = .interval
    public var intervalHours: Int = 4
    public var times: [ScheduledTime] = [ScheduledTime(weekdays: [2, 3, 4, 5, 6], hour: 2)]
    public var idleMinutes: Int = 15
    public var idleMinHoursBetween: Int = 4
    public var skipOnBattery: Bool = true
    public var forbiddenWindow: TimeWindow?
    /// nil = all destinations (Time Machine default).
    public var destinationID: String?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BackupConfig()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        mode = try c.decodeIfPresent(ScheduleMode.self, forKey: .mode) ?? d.mode
        intervalHours = try c.decodeIfPresent(Int.self, forKey: .intervalHours) ?? d.intervalHours
        times = try c.decodeIfPresent([ScheduledTime].self, forKey: .times) ?? d.times
        idleMinutes = try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? d.idleMinutes
        idleMinHoursBetween = try c.decodeIfPresent(Int.self, forKey: .idleMinHoursBetween) ?? d.idleMinHoursBetween
        skipOnBattery = try c.decodeIfPresent(Bool.self, forKey: .skipOnBattery) ?? d.skipOnBattery
        forbiddenWindow = try c.decodeIfPresent(TimeWindow.self, forKey: .forbiddenWindow)
        destinationID = try c.decodeIfPresent(String.self, forKey: .destinationID)
    }

    /// Clamps values to the ranges in the spec.
    public var sanitized: BackupConfig {
        var c = self
        c.intervalHours = min(max(intervalHours, 1), 168)
        c.idleMinutes = min(max(idleMinutes, 5), 120)
        c.idleMinHoursBetween = min(max(idleMinHoursBetween, 1), 168)
        return c
    }
}

public struct BackupState: Codable, Equatable, Sendable {
    public var lastStartedAt: Date?
    public var lastCheckAt: Date?
    public var lastDecision: String?
    public var lastError: String?
    public var pausedUntil: Date?

    public init() {}
}
