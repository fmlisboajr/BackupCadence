import Foundation
import BackupCadenceCore

/// Installs/removes the per-user LaunchAgent that runs the agent every 5 minutes.
struct LaunchAgentManager {
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    /// The agent binary sits next to the app executable (Contents/MacOS/backupcadence-agent).
    static var agentPath: String {
        let dir = Bundle.main.executableURL?.deletingLastPathComponent() ?? Bundle.main.bundleURL
        return dir.appendingPathComponent("backupcadence-agent").path
    }

    private static var domain: String { "gui/\(getuid())" }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func install() throws {
        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [agentPath, "tick"],
            "StartInterval": 300,
            "RunAtLoad": true,
            "ProcessType": "Background",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
        _ = try? runProcess("/bin/launchctl", ["bootout", "\(domain)/\(launchAgentLabel)"])
        let out = try runProcess("/bin/launchctl", ["bootstrap", domain, plistURL.path])
        if out.status != 0 { throw AppError.message("launchctl bootstrap failed: \(out.stderr)") }
    }

    static func uninstall() throws {
        _ = try? runProcess("/bin/launchctl", ["bootout", "\(domain)/\(launchAgentLabel)"])
        try? FileManager.default.removeItem(at: plistURL)
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let m) = self { return m }
        return nil
    }
}
