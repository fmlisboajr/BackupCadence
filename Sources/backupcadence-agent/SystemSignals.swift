import CoreGraphics
import Foundation
import IOKit.ps
import BackupCadenceCore

struct LiveSignals: SystemSignals {
    func onBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? else {
            return false
        }
        return type == kIOPSBatteryPowerValue
    }

    func idleSeconds() -> TimeInterval {
        // ~0 is kCGAnyInputEventType.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
