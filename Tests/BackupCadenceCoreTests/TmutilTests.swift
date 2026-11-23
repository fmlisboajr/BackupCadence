import Testing
import Foundation
@testable import BackupCadenceCore

@Suite struct TmutilTests {
    @Test func statusPlistIdle() throws {
        let xml = #"<?xml version="1.0"?><plist version="1.0"><dict><key>Percent</key><real>-1</real><key>Running</key><false/></dict></plist>"#
        #expect(try TmutilParsing.parseStatusPlist(Data(xml.utf8)) == TMStatus(isRunning: false))
    }
    @Test func statusPlistRunning() throws {
        let xml = #"<?xml version="1.0"?><plist version="1.0"><dict><key>BackupPhase</key><string>Copying</string><key>Percent</key><real>0.5</real><key>Running</key><string>1</string></dict></plist>"#
        #expect(try TmutilParsing.parseStatusPlist(Data(xml.utf8)) == TMStatus(isRunning: true, phase: "Copying", percent: 0.5))
    }
    @Test func statusText() {
        let t = "Backup session status:\n{\n    BackupPhase = Copying;\n    Percent = \"0.25\";\n    Running = 1;\n}"
        #expect(TmutilParsing.parseStatusText(t) == TMStatus(isRunning: true, phase: "Copying", percent: 0.25))
        #expect(TmutilParsing.parseStatusText("{\n Running = 0;\n}").isRunning == false)
    }
    @Test func latestBackupPath() {
        let d = TmutilParsing.parseLatestBackup("/Volumes/TM/Backups.backupdb/Mac/2026-11-22-101530\n", calendar: utc)
        #expect(d == date(22, 10, 15).addingTimeInterval(30))
        #expect(TmutilParsing.parseLatestBackup("/Volumes/TM/2026-11-22-101530.backup", calendar: utc) != nil)
        #expect(TmutilParsing.parseLatestBackup("nothing here") == nil)
    }
    @Test func destinations() throws {
        let xml = #"<?xml version="1.0"?><plist version="1.0"><dict><key>Destinations</key><array><dict><key>ID</key><string>A</string><key>Name</key><string>Disk</string><key>Kind</key><string>Local</string></dict></array></dict></plist>"#
        #expect(try TmutilParsing.parseDestinations(Data(xml.utf8)) == [TMDestination(id: "A", name: "Disk", kind: "Local")])
    }
}
