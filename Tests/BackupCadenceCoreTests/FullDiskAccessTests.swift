import Testing
@testable import BackupCadenceCore

@Suite struct FullDiskAccessTests {
    @Test func readableMeansGranted() {
        #expect(hasFullDiskAccess(paths: ["a"], probe: { _ in .readable }))
    }
    @Test func deniedMeansMissing() {
        #expect(!hasFullDiskAccess(paths: ["a", "b"], probe: { _ in .denied }))
    }
    @Test func missingFileFallsThroughToNext() {
        #expect(hasFullDiskAccess(paths: ["a", "b"], probe: { $0 == "a" ? .missing : .readable }))
        #expect(!hasFullDiskAccess(paths: ["a"], probe: { _ in .missing }))
    }
    @Test func decisionBothWays() {
        #expect(schedulingAction(hasFullDiskAccess: true) == .runAdminPrompt)
        #expect(schedulingAction(hasFullDiskAccess: false) == .needFullDiskAccess)
    }
}
