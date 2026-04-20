import Foundation
import IOKit.pwr_mgt

// MARK: - Protocol

/// Abstraction over IOKit power assertions so tests can mock this layer.
protocol WakeAssertionControlling {
    /// Begin keeping the Mac (and optionally display) awake.
    /// - Parameter allowDisplaySleep: If `true`, only system sleep is blocked;
    ///   the display may still dim and sleep normally.
    /// - Parameter allowPowerNap: If `true`, uses `PreventSystemSleep` instead of
    ///   `PreventUserIdleSystemSleep`, which allows Power Nap (background
    ///   syncs, Time Machine, push email) while still blocking user-initiated sleep.
    func activate(allowDisplaySleep: Bool, allowPowerNap: Bool) throws
    func deactivate()
}

/// Convenience overload preserving backward compatibility.
extension WakeAssertionControlling {
    func activate(allowDisplaySleep: Bool) throws {
        try activate(allowDisplaySleep: allowDisplaySleep, allowPowerNap: false)
    }
}

enum WakeAssertionError: Error {
    case couldNotCreateAssertion(String)
}

// MARK: - Live implementation

/// Manages IOKit power assertions for KeepAwake sessions.
///
/// ## Assertion types
///
/// | Setting                   | IOKit type                                  | Effect                                      |
/// |---------------------------|---------------------------------------------|---------------------------------------------|
/// | Default (Power Nap off)   | `PreventUserIdleSystemSleep`                | Blocks idle sleep; no background tasks      |
/// | Power Nap on              | `PreventSystemSleep`                        | Blocks sleep; allows Power Nap syncs        |
/// | Allow Display Sleep off   | + `PreventUserIdleDisplaySleep`             | Also keeps the display awake                |
///
/// A separate `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion is
/// created when `allowDisplaySleep` is `false`.
final class LiveWakeAssertionController: WakeAssertionControlling {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    func activate(allowDisplaySleep: Bool, allowPowerNap: Bool) throws {
        deactivate()

        // Power Nap-aware system sleep assertion:
        //   PreventSystemSleep     → allows Power Nap (background syncs, Time Machine)
        //   PreventUserIdleSystemSleep → standard "stay awake while user is idle"
        let systemType: CFString = allowPowerNap
            ? kIOPMAssertionTypePreventSystemSleep as CFString
            : kIOPMAssertionTypePreventUserIdleSystemSleep as CFString

        let systemName = allowPowerNap
            ? "KeepAwake — preventing sleep (Power Nap allowed)" as CFString
            : "KeepAwake — preventing idle system sleep" as CFString

        try createAssertion(type: systemType, name: systemName, id: &systemAssertionID)

        if !allowDisplaySleep {
            try createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                name: "KeepAwake — keeping display on" as CFString,
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

    // MARK: - Private

    private func createAssertion(type: CFString, name: CFString, id: inout IOPMAssertionID) throws {
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &id
        )
        guard result == kIOReturnSuccess else {
            throw WakeAssertionError.couldNotCreateAssertion(name as String)
        }
    }
}
