import Foundation
import AppKit
import Observation
import ServiceManagement
import BackupCadenceCore

enum IconState { case idle, running, paused, error }

@MainActor
@Observable
final class AppModel {
    private let store = Store()
    private let client = TmutilClient()

    var config: BackupConfig { didSet { if config != oldValue { try? store.saveConfig(config) } } }
    var state: BackupState
    var tmStatus = TMStatus(isRunning: false)
    var lastBackup: Date?
    var destinations: [TMDestination] = []
    var errorMessage: String?
    var launchAtLogin: Bool
    var fullDiskAccess: Bool = hasFullDiskAccess()
    var timeMachineAuto: Bool? = timeMachineAutoBackupEnabled()

    init() {
        config = store.loadConfig()
        state = store.loadState()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refresh()
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.refresh()
            }
        }
    }

    var iconName: String {
        switch iconState {
        case .idle: return "externaldrive"
        case .running: return "arrow.triangle.2.circlepath"
        case .paused: return "pause.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var iconState: IconState {
        if errorMessage != nil || state.lastError != nil { return .error }
        if tmStatus.isRunning { return .running }
        if isPaused { return .paused }
        return .idle
    }

    var isPaused: Bool { (state.pausedUntil ?? .distantPast) > Date() }

    var nextBackup: Date? {
        predictNextBackup(now: Date(), config: config, lastBackup: effectiveLast, pausedUntil: state.pausedUntil)
    }

    private var effectiveLast: Date? { [lastBackup, state.lastStartedAt].compactMap { $0 }.max() }

    func refresh() {
        fullDiskAccess = hasFullDiskAccess()
        timeMachineAuto = timeMachineAutoBackupEnabled()
        state = store.loadState()
        let client = client
        Task {
            let (status, last, dests) = await Task.detached {
                (try? client.status(), try? client.latestBackup(), try? client.destinations())
            }.value
            if let status { tmStatus = status }
            if let last { lastBackup = last }
            if let dests { destinations = dests }
        }
    }

    func backUpNow() {
        let runner = TickRunner(store: store, client: client, signals: NoSignals())
        Task {
            let result = await Task.detached { runner.backupNow() }.value
            errorMessage = result.error
            if let e = result.error { logAppError("backUpNow: \(e)") }
            refresh()
        }
    }

    func pause(for interval: TimeInterval) { setPause(Date().addingTimeInterval(interval)) }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        setPause(cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!))
    }

    func resume() { setPause(nil) }

    private func setPause(_ date: Date?) {
        var s = store.loadState()
        s.pausedUntil = date
        try? store.saveState(s)
        state = s
    }

    private func logAppError(_ message: String) {
        AgentLog(url: store.paths.logURL).append("app error: \(message)")
    }

    func openFullDiskAccessSettings() {
        for s in fullDiskAccessURLs {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { return }
        }
    }

    /// Turn scheduling on/off: flip Time Machine's AutoBackup (admin prompt) + LaunchAgent.
    func setEnabled(_ on: Bool) {
        var step = "admin"
        do {
            if on {
                try AdminPrivileges.setTimeMachineAutomatic(false)
                step = "LaunchAgent install"
                try LaunchAgentManager.install()
            } else {
                step = "LaunchAgent uninstall"
                try LaunchAgentManager.uninstall()
                step = "admin"
                try AdminPrivileges.setTimeMachineAutomatic(true)
            }
            config.enabled = on
            errorMessage = nil
        } catch {
            // No rollback (avoids a second password prompt); config.enabled stays as it was.
            errorMessage = error.localizedDescription
            logAppError("setEnabled(\(on)) failed at \(step): \(error.localizedDescription)")
        }
        timeMachineAuto = timeMachineAutoBackupEnabled()
    }

    var autoBackupConflict: AutoBackupConflict? {
        BackupCadenceCore.autoBackupConflict(schedulingOn: config.enabled, timeMachineAuto: timeMachineAuto)
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = error.localizedDescription
            logAppError("setLaunchAtLogin(\(on)) failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var logURL: URL { store.paths.logURL }
}

/// Manual backups ignore signals; this satisfies the runner's initializer.
private struct NoSignals: SystemSignals {
    func onBattery() -> Bool { false }
    func idleSeconds() -> TimeInterval { 0 }
}
