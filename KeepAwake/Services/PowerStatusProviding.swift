import Foundation
import IOKit.ps

protocol PowerStatusProviding {
    func currentSnapshot() -> PowerSnapshot
}

struct LivePowerStatusProvider: PowerStatusProviding {
    func currentSnapshot() -> PowerSnapshot {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array
        let description = list.first.flatMap { IOPSGetPowerSourceDescription(info, $0).takeUnretainedValue() as? [String: Any] }
        let batteryLevel = description?[kIOPSCurrentCapacityKey as String] as? Int

        return PowerSnapshot(
            batteryLevel: batteryLevel,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
