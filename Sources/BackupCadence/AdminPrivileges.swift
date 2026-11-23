import Foundation
import BackupCadenceCore

/// Flips Time Machine's AutoBackup root preference through the standard macOS admin prompt.
/// The password is never seen by the app. (`tmutil enable/disable` is not used: the elevated
/// process does not inherit the app's Full Disk Access.) Only fixed strings are run.
@MainActor
enum AdminPrivileges {
    static func setTimeMachineAutomatic(_ enabled: Bool) throws {
        let source = enabled
            ? "do shell script \"/usr/bin/defaults write /Library/Preferences/com.apple.TimeMachine AutoBackup -bool true\" with administrator privileges"
            : "do shell script \"/usr/bin/defaults write /Library/Preferences/com.apple.TimeMachine AutoBackup -bool false\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else { throw AppError.message("Could not build script") }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let msg = (error[NSAppleScript.errorMessage] as? String) ?? "unknown error"
            let num = (error[NSAppleScript.errorNumber] as? Int).map(String.init) ?? "?"
            throw AppError.message("\(msg) (AppleScript error \(num); full: \(error))")
        }
        let now = timeMachineAutoBackupEnabled()
        guard now == enabled else {
            throw AppError.message("Time Machine setting did not change (AutoBackup is \(now.map { $0 ? "on" : "off" } ?? "unknown"), expected \(enabled ? "on" : "off"))")
        }
    }
}
