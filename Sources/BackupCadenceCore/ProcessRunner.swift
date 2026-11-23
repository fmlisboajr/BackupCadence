import Foundation

public struct ProcessOutput: Sendable {
    public var status: Int32
    public var stdout: Data
    public var stderr: String
}

public func runProcess(_ executable: String, _ arguments: [String]) throws -> ProcessOutput {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: executable)
    p.arguments = arguments
    let out = Pipe(), err = Pipe()
    p.standardOutput = out
    p.standardError = err
    try p.run()
    // Drain stderr on a background queue to avoid pipe deadlocks.
    nonisolated(unsafe) var errData = Data()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
        errData = err.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }
    let outData = out.fileHandleForReading.readDataToEndOfFile()
    group.wait()
    p.waitUntilExit()
    return ProcessOutput(status: p.terminationStatus, stdout: outData, stderr: String(decoding: errData, as: UTF8.self))
}
