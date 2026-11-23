import Foundation

public struct AppPaths: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static var standard: AppPaths {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return AppPaths(directory: base.appendingPathComponent("BackupCadence", isDirectory: true))
    }

    public var configURL: URL { directory.appendingPathComponent("config.json") }
    public var stateURL: URL { directory.appendingPathComponent("state.json") }
    public var logURL: URL { directory.appendingPathComponent("agent.log") }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

public let launchAgentLabel = "com.backupcadence.agent"
