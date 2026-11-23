import Foundation

public protocol SystemSignals: Sendable {
    func onBattery() -> Bool
    func idleSeconds() -> TimeInterval
}

public struct TickResult: Equatable, Sendable {
    public var decision: Decision
    public var started: Bool
    public var error: String?
}

/// One agent run: collects signals, applies the rule and (unless dry-run) starts the backup.
public struct TickRunner: Sendable {
    public let store: Store
    public let log: AgentLog
    public let client: TimeMachineClient
    public let signals: SystemSignals
    public let calendar: Calendar

    public init(store: Store, client: TimeMachineClient, signals: SystemSignals, calendar: Calendar = .current) {
        self.store = store
        self.log = AgentLog(url: store.paths.logURL)
        self.client = client
        self.signals = signals
        self.calendar = calendar
    }

    public func tick(now: Date = Date(), dryRun: Bool) -> TickResult {
        let config = store.loadConfig()
        var state = store.loadState()
        var warnings: [String] = []

        let running: Bool
        do { running = try client.status().isRunning } catch {
            return fail("status unavailable: \(error.localizedDescription)", dryRun: dryRun, state: &state, now: now)
        }
        let latest: Date?
        do { latest = try client.latestBackup() } catch {
            latest = nil
            warnings.append("latestbackup unavailable (grant Full Disk Access?)")
        }
        let last = [latest, state.lastStartedAt].compactMap { $0 }.max()

        let decision = decide(
            now: now, config: config, lastBackup: last,
            onBattery: signals.onBattery(), idleSeconds: signals.idleSeconds(),
            isRunning: running, pausedUntil: state.pausedUntil, calendar: calendar)

        var started = false
        if decision == .start && !dryRun {
            do { try client.startBackup(destinationID: config.destinationID); started = true } catch {
                self.log.append("error: could not start backup: \(error.localizedDescription)", at: now)
                state.lastError = error.localizedDescription
                state.lastCheckAt = now
                try? store.saveState(state)
                return TickResult(decision: decision, started: false, error: error.localizedDescription)
            }
        }
        if !dryRun {
            var fresh = store.loadState()  // the app may have changed the pause meanwhile
            fresh.lastCheckAt = now
            fresh.lastDecision = decision.summary
            fresh.lastError = nil
            if started { fresh.lastStartedAt = now }
            try? store.saveState(fresh)
            log.append(started ? "started backup" : decision.summary, at: now)
            for w in warnings { log.append("warning: \(w)", at: now) }
        }
        return TickResult(decision: decision, started: started, error: nil)
    }

    /// "Back up now": ignores schedule and constraints, only refuses if one is already running.
    public func backupNow(now: Date = Date()) -> TickResult {
        let config = store.loadConfig()
        if let running = try? client.status().isRunning, running {
            log.append("manual backup skipped: \(SkipReason.alreadyRunning.text)", at: now)
            return TickResult(decision: .skip(.alreadyRunning), started: false, error: nil)
        }
        do {
            try client.startBackup(destinationID: config.destinationID)
            var state = store.loadState()
            state.lastStartedAt = now
            state.lastCheckAt = now
            state.lastDecision = "manual backup started"
            state.lastError = nil
            try? store.saveState(state)
            log.append("started backup (manual)", at: now)
            return TickResult(decision: .start, started: true, error: nil)
        } catch {
            log.append("error: could not start manual backup: \(error.localizedDescription)", at: now)
            return TickResult(decision: .start, started: false, error: error.localizedDescription)
        }
    }

    private func fail(_ message: String, dryRun: Bool, state: inout BackupState, now: Date) -> TickResult {
        if !dryRun {
            log.append("error: \(message)", at: now)
            state.lastError = message
            state.lastCheckAt = now
            try? store.saveState(state)
        }
        return TickResult(decision: .skip(.notDue(next: nil)), started: false, error: message)
    }
}
