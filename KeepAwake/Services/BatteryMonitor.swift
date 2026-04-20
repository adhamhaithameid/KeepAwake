import AppKit
import CoreFoundation
import Foundation
import IOKit.ps

/// Observes IOKit battery/power-source notifications using
/// `IOPSNotificationCreateRunLoopSource` — the same push mechanism
/// the macOS menu bar battery indicator uses.
///
/// This replaces the 30-second polling approach and gives sub-second
/// reaction time to battery drops.
@MainActor
final class BatteryMonitor {
    private var runLoopSource: CFRunLoopSource?
    /// Called whenever battery state changes (charge level, charge state, etc.)
    var onBatteryChange: (() -> Void)?

    func start() {
        guard runLoopSource == nil else { return }

        // The C callback must capture self via an opaque pointer.
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let source = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context else { return }
                let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
                // Dispatch to main so callers don't need to worry about threading.
                DispatchQueue.main.async {
                    monitor.onBatteryChange?()
                }
            },
            selfPtr
        )

        if let src = source?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
            runLoopSource = src
        }
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            runLoopSource = nil
        }
    }

    deinit {
        // CFRunLoopSource cleanup must happen on the main thread;
        // we accept the source leaks until the process exits (menu bar app lifecycle).
    }
}
