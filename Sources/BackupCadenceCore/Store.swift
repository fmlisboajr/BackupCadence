import Foundation

/// Reads and writes config.json and state.json.
public struct Store: Sendable {
    public let paths: AppPaths

    public init(paths: AppPaths = .standard) { self.paths = paths }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func loadConfig() -> BackupConfig {
        load(BackupConfig.self, from: paths.configURL) ?? BackupConfig()
    }

    public func saveConfig(_ config: BackupConfig) throws {
        try save(config.sanitized, to: paths.configURL)
    }

    public func loadState() -> BackupState {
        load(BackupState.self, from: paths.stateURL) ?? BackupState()
    }

    public func saveState(_ state: BackupState) throws {
        try save(state, to: paths.stateURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try paths.ensureDirectory()
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
