import Foundation

/// Time Machine's "Back Up Automatically" switch lives in the root preference
/// /Library/Preferences/com.apple.TimeMachine, key AutoBackup. It is world-readable.
public let timeMachinePrefsDomain = "/Library/Preferences/com.apple.TimeMachine"
public let timeMachineAutoBackupKey = "AutoBackup"

/// Parses the output of `defaults read <domain> AutoBackup`: "1" -> true, "0" -> false, anything else -> nil.
public func parseAutoBackup(_ output: String) -> Bool? {
    switch output.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "1": return true
    case "0": return false
    default: return nil
    }
}

/// Current value of Time Machine's automatic backups; nil when the key is missing or unreadable.
public func timeMachineAutoBackupEnabled(
    run: (String, [String]) throws -> ProcessOutput = runProcess
) -> Bool? {
    guard let out = try? run("/usr/bin/defaults", ["read", timeMachinePrefsDomain, timeMachineAutoBackupKey]),
          out.status == 0 else { return nil }
    return parseAutoBackup(String(decoding: out.stdout, as: UTF8.self))
}

/// Which warning (if any) the menu should show about the two schedulers.
public enum AutoBackupConflict: Sendable, Equatable { case doubleBackups, noBackups }

public func autoBackupConflict(schedulingOn: Bool, timeMachineAuto: Bool?) -> AutoBackupConflict? {
    guard let auto = timeMachineAuto else { return nil }
    if schedulingOn && auto { return .doubleBackups }
    if !schedulingOn && !auto { return .noBackups }
    return nil
}

/// What turning scheduling on should do, given Time Machine's automatic setting.
public enum EnableDecision: Sendable, Equatable { case install, needManualFrequency }

/// Automatic on -> the user must first set the frequency to Manually; off or unknown -> install.
public func enableDecision(autoBackup: Bool?) -> EnableDecision {
    autoBackup == true ? .needManualFrequency : .install
}

/// System Settings locations for Time Machine, tried in order.
public let timeMachineSettingsURLs = [
    "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension",
    "x-apple.systempreferences:com.apple.preference.TimeMachine",
    "file:///System/Library/PreferencePanes/TimeMachine.prefPane",
]
