import Testing
import Foundation
@testable import BackupCadenceCore

@Suite struct AutoBackupTests {
    @Test func parsesOneZeroAndGarbage() {
        #expect(parseAutoBackup("1\n") == true)
        #expect(parseAutoBackup("0\n") == false)
        #expect(parseAutoBackup("") == nil)
        #expect(parseAutoBackup("maybe") == nil)
    }

    private func out(_ status: Int32, _ text: String) -> ProcessOutput {
        ProcessOutput(status: status, stdout: Data(text.utf8), stderr: "")
    }

    @Test func readerUsesDefaultsRead() {
        var captured: [String] = []
        let v = timeMachineAutoBackupEnabled(run: { exe, args in captured = [exe] + args; return out(0, "1\n") })
        #expect(v == true)
        #expect(captured == ["/usr/bin/defaults", "read", "/Library/Preferences/com.apple.TimeMachine", "AutoBackup"])
    }

    @Test func missingKeyOrFailureIsNil() {
        #expect(timeMachineAutoBackupEnabled(run: { _, _ in out(1, "") }) == nil)
        #expect(timeMachineAutoBackupEnabled(run: { _, _ in throw TimeMachineError.unparsable("x") }) == nil)
    }

    @Test func conflicts() {
        #expect(autoBackupConflict(schedulingOn: true, timeMachineAuto: true) == .doubleBackups)
        #expect(autoBackupConflict(schedulingOn: false, timeMachineAuto: false) == .noBackups)
        #expect(autoBackupConflict(schedulingOn: true, timeMachineAuto: false) == nil)
        #expect(autoBackupConflict(schedulingOn: false, timeMachineAuto: true) == nil)
        #expect(autoBackupConflict(schedulingOn: true, timeMachineAuto: nil) == nil)
    }
}
