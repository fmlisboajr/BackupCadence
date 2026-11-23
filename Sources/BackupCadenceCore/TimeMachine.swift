import Foundation

public struct TMStatus: Equatable, Sendable {
    public var isRunning: Bool
    public var phase: String?
    public var percent: Double?

    public init(isRunning: Bool, phase: String? = nil, percent: Double? = nil) {
        self.isRunning = isRunning
        self.phase = phase
        self.percent = percent
    }
}

public struct TMDestination: Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: String?

    public init(id: String, name: String, kind: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// Access to the `tmutil` tool. Tests use a fake.
public protocol TimeMachineClient: Sendable {
    func status() throws -> TMStatus
    func latestBackup() throws -> Date?
    func destinations() throws -> [TMDestination]
    func startBackup(destinationID: String?) throws
}

public enum TimeMachineError: Error, LocalizedError, Equatable {
    case commandFailed(String, Int32, String)
    case unparsable(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let code, let msg):
            return "tmutil \(cmd) failed (\(code)): \(msg.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .unparsable(let what): return "could not parse tmutil \(what)"
        }
    }
}
