import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: KeepAwakeAppEnvironment?

    // Set accessory policy as early as possible — before the run loop begins —
    // so RunningBoard never waits for a window that will never appear.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.makeEnvironment()
        self.environment = env
        Task {
            await env.controller.handleLaunch()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let controller = environment?.controller {
            let sema = DispatchSemaphore(value: 0)
            Task {
                await controller.handleTermination()
                sema.signal()
            }
            sema.wait()
        }
    }
}
