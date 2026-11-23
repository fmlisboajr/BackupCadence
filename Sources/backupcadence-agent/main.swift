import Foundation
import BackupCadenceCore

let usage = """
usage: backupcadence-agent <command>
  tick [--dry-run]   decide whether to start a backup (dry-run never starts one)
  now                start a backup immediately, ignoring schedule and constraints
  status             show config, state and Time Machine status
"""

func printStatus(store: Store, client: TimeMachineClient, signals: SystemSignals) {
    let config = store.loadConfig()
    let state = store.loadState()
    print("scheduling: \(config.enabled ? "on" : "off"), mode: \(config.mode.rawValue)")
    if let st = try? client.status() {
        print("time machine: \(st.isRunning ? "running" : "idle")" + (st.phase.map { " (\($0))" } ?? ""))
    } else {
        print("time machine: status unavailable")
    }
    let latest = try? client.latestBackup()
    if latest == nil { print("last backup: unknown (latestbackup needs Full Disk Access)") }
    else if let latest { print("last backup: \(latest.formatted())") }
    let last = [latest ?? nil, state.lastStartedAt].compactMap { $0 }.max()
    let next = predictNextBackup(now: Date(), config: config, lastBackup: last, pausedUntil: state.pausedUntil)
    print("next backup: \(next?.formatted() ?? "none")")
    print("paused until: \(state.pausedUntil.map { $0.formatted() } ?? "-")")
    print("on battery: \(signals.onBattery()), idle: \(Int(signals.idleSeconds()))s")
    print("last decision: \(state.lastDecision ?? "-")")
    if let e = state.lastError { print("last error: \(e)") }
    if let dests = try? client.destinations() {
        for d in dests { print("destination: \(d.name) [\(d.id)]\(d.id == config.destinationID ? " (selected)" : "")") }
    }
}

let args = Array(CommandLine.arguments.dropFirst())
let store = Store()
let client = TmutilClient()
let signals = LiveSignals()
let runner = TickRunner(store: store, client: client, signals: signals)

switch args.first {
case "tick":
    let dry = args.contains("--dry-run")
    let result = runner.tick(dryRun: dry)
    if let e = result.error { print("error: \(e)") }
    print("decision: \(result.decision.summary)" + (dry ? " (dry run, nothing started)" : ""))
    exit(result.error == nil ? 0 : 1)
case "now":
    let result = runner.backupNow()
    if let e = result.error { print("error: \(e)"); exit(1) }
    print(result.started ? "backup started" : "skipped: \(result.decision.summary)")
case "status":
    printStatus(store: store, client: client, signals: signals)
default:
    print(usage)
    exit(args.isEmpty ? 0 : 64)
}
