import Foundation

/// Append-only text log, capped at `maxLines` (oldest lines dropped).
public struct AgentLog: Sendable {
    public static let maxLines = 1000
    public let url: URL

    public init(url: URL) { self.url = url }

    public func append(_ message: String, at date: Date = Date()) {
        let line = "\(date.formatted(.iso8601)) \(message)"
        var lines = readLines()
        lines.append(line)
        write(Array(lines.suffix(Self.maxLines)))
    }

    public func readLines() -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    private func write(_ lines: [String]) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
