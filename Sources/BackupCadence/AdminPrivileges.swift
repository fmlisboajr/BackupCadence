import Foundation

/// Runs `tmutil enable/disable` through the standard macOS admin prompt. The password is never seen by the app.
@MainActor
enum AdminPrivileges {
    static func setTimeMachineAutomatic(_ enabled: Bool) throws {
        let verb = enabled ? "enable" : "disable"
        let source = "do shell script \"/usr/bin/tmutil \(verb)\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else { throw AppError.message("Could not build script") }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let msg = (error[NSAppleScript.errorMessage] as? String) ?? "unknown error"
            throw AppError.message(msg)
        }
    }
}
