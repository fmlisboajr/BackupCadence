import SwiftUI
import BackupCadenceCore

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusText)
        Text("Mode: \(modeName)")
        Text("Last backup: \(format(model.lastBackup))")
        Text("Next backup: \(model.config.enabled ? format(model.nextBackup) : String(localized: "scheduling off"))")
        if let e = model.errorMessage ?? model.state.lastError {
            Text("Error: \(e)")
        }
        if let c = model.autoBackupConflict {
            switch c {
            case .doubleBackups: Text("Warning: Time Machine automatic backups are also on (double backups)")
            case .noBackups: Text("Time Machine automatic backups are off and scheduling is off: no backups will run")
            }
        }
        Divider()
        Button("Back up now") { model.backUpNow() }
            .disabled(model.tmStatus.isRunning)
        if model.isPaused {
            Button("Resume") { model.resume() }
        } else {
            Button("Pause for 1 hour") { model.pause(for: 3600) }
            Button("Pause until tomorrow") { model.pauseUntilTomorrow() }
        }
        Divider()
        Button("Preferences…") {
            openWindow(id: "preferences")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Button("View log") { openLog() }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusText: String {
        switch model.iconState {
        case .running: return String(localized: "Status: backing up")
        case .paused: return String(localized: "Status: paused")
        case .error: return String(localized: "Status: error")
        case .idle: return String(localized: "Status: idle")
        }
    }

    private var modeName: String {
        switch model.config.mode {
        case .interval: return String(localized: "Interval")
        case .times: return String(localized: "Specific times")
        case .idle: return String(localized: "When idle")
        }
    }

    private func format(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .shortened) ?? String(localized: "unknown")
    }

    private func openLog() {
        try? FileManager.default.createDirectory(at: model.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: model.logURL.path) {
            try? Data().write(to: model.logURL)
        }
        NSWorkspace.shared.open(model.logURL)
    }
}
