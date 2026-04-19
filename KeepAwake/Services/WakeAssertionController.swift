import Foundation
import IOKit.pwr_mgt

protocol WakeAssertionControlling {
    func activate(allowDisplaySleep: Bool) throws
    func deactivate()
}

enum WakeAssertionError: Error {
    case couldNotCreateAssertion(String)
}

final class LiveWakeAssertionController: WakeAssertionControlling {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    func activate(allowDisplaySleep: Bool) throws {
        deactivate()

        try createAssertion(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            name: "KeepAwake keeps the Mac active" as CFString,
            id: &systemAssertionID
        )

        if !allowDisplaySleep {
            try createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                name: "KeepAwake keeps the display on" as CFString,
                id: &displayAssertionID
            )
        }
    }

    func deactivate() {
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }

        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func createAssertion(type: CFString, name: CFString, id: inout IOPMAssertionID) throws {
        let result = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), name, &id)
        guard result == kIOReturnSuccess else {
            throw WakeAssertionError.couldNotCreateAssertion(name as String)
        }
    }
}
