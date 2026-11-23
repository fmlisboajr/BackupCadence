import Testing
import Foundation
@testable import BackupCadenceCore

@Suite struct RunnerTests {
    func makeStore() -> Store {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bc-\(UUID().uuidString)")
        return Store(paths: AppPaths(directory: dir))
    }

    @Test func dryRunNeverStartsOrWrites() throws {
        let store = makeStore()
        try store.saveConfig(config(.interval))
        let client = FakeClient()
        let runner = TickRunner(store: store, client: client, signals: FakeSignals(), calendar: utc)
        let r = runner.tick(now: date(23, 12), dryRun: true)
        #expect(r.decision == .start)
        #expect(!r.started)
        #expect(client.started == 0)
        #expect(!FileManager.default.fileExists(atPath: store.paths.logURL.path))
    }

    @Test func realTickStartsWithDestinationAndLogs() throws {
        let store = makeStore()
        try store.saveConfig(config(.interval) { $0.destinationID = "DEST" })
        let client = FakeClient()
        let runner = TickRunner(store: store, client: client, signals: FakeSignals(), calendar: utc)
        let r = runner.tick(now: date(23, 12), dryRun: false)
        #expect(r.started)
        #expect(client.started == 1)
        #expect(client.startedDestination == .some("DEST"))
        #expect(store.loadState().lastStartedAt == date(23, 12))
        // A second tick right away must not start again (interval not elapsed).
        #expect(runner.tick(now: date(23, 12, 5), dryRun: false).started == false)
        #expect(client.started == 1)
    }

    @Test func logIsCappedAt1000Lines() {
        let log = AgentLog(url: makeStore().paths.logURL)
        for i in 0..<1105 { log.append("line \(i)") }
        let lines = log.readLines()
        #expect(lines.count == 1000)
        #expect(lines.last?.hasSuffix("line 1104") == true)
        #expect(lines.first?.hasSuffix("line 105") == true)
    }

    @Test func configRoundTripAndSanitize() throws {
        let store = makeStore()
        var c = config(.times) { $0.intervalHours = 9999; $0.forbiddenWindow = TimeWindow(startMinute: 60, endMinute: 120) }
        c.idleMinutes = 1
        try store.saveConfig(c)
        let loaded = store.loadConfig()
        #expect(loaded.intervalHours == 168)
        #expect(loaded.idleMinutes == 5)
        #expect(loaded.mode == .times)
        #expect(loaded.forbiddenWindow == c.forbiddenWindow)
    }
}
