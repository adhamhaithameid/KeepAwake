import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    private var environment: KeepAwakeAppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
            let environment = AppEnvironment.makeEnvironment()
            self.environment = environment
            await environment.controller.handleLaunch()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
