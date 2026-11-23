import Foundation

public enum ProbeResult: Sendable, Equatable { case readable, denied, missing }

/// Full Disk Access detection.
///
/// Approach: try to open for reading files that exist on every Mac and that macOS protects with TCC
/// (kTCCServiceSystemPolicyAllFiles): the system TCC database, then the user TCC database. Without
/// Full Disk Access `open(2)` fails with EPERM/EACCES; with it, it succeeds. ENOENT tells nothing,
/// so the next path is tried. If no probe gives a definite answer we report "not granted".
/// The grant belongs to the app/binary identity: rebuilding with ad hoc signing changes it and
/// invalidates the grant.
public let fullDiskAccessProbePaths: [String] = [
    "/Library/Application Support/com.apple.TCC/TCC.db",
    NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
]

public func probeOpenForRead(_ path: String) -> ProbeResult {
    let fd = open(path, O_RDONLY)
    if fd >= 0 { close(fd); return .readable }
    return (errno == ENOENT) ? .missing : .denied
}

public func hasFullDiskAccess(
    paths: [String] = fullDiskAccessProbePaths,
    probe: (String) -> ProbeResult = probeOpenForRead
) -> Bool {
    for p in paths {
        switch probe(p) {
        case .readable: return true
        case .denied: return false
        case .missing: continue
        }
    }
    return false
}

/// What the app should do when the user turns scheduling on.
public enum SchedulingAction: Sendable, Equatable { case runAdminPrompt, needFullDiskAccess }

/// Pure decision: without Full Disk Access `tmutil disable` cannot work, so do not prompt for a password.
public func schedulingAction(hasFullDiskAccess: Bool) -> SchedulingAction {
    hasFullDiskAccess ? .runAdminPrompt : .needFullDiskAccess
}

public let fullDiskAccessURLs = [
    "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
    "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
]
