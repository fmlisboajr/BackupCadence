import Foundation

/// Real implementation backed by /usr/bin/tmutil. Only `startBackup` changes anything.
public struct TmutilClient: TimeMachineClient {
    public static let path = "/usr/bin/tmutil"

    public init() {}

    private func run(_ args: [String]) throws -> ProcessOutput {
        let out = try runProcess(Self.path, args)
        guard out.status == 0 else {
            let msg = out.stderr.isEmpty ? String(decoding: out.stdout, as: UTF8.self) : out.stderr
            throw TimeMachineError.commandFailed(args.joined(separator: " "), out.status, msg)
        }
        return out
    }

    public func status() throws -> TMStatus {
        if let out = try? run(["status", "-X"]), let s = try? TmutilParsing.parseStatusPlist(out.stdout) {
            return s
        }
        let out = try run(["status"])
        return TmutilParsing.parseStatusText(String(decoding: out.stdout, as: UTF8.self))
    }

    public func latestBackup() throws -> Date? {
        let out = try run(["latestbackup"])
        return TmutilParsing.parseLatestBackup(String(decoding: out.stdout, as: UTF8.self))
    }

    public func destinations() throws -> [TMDestination] {
        try TmutilParsing.parseDestinations(try run(["destinationinfo", "-X"]).stdout)
    }

    public func startBackup(destinationID: String?) throws {
        var args = ["startbackup"]
        if let destinationID { args += ["--destination", destinationID] }
        _ = try run(args)
    }
}
