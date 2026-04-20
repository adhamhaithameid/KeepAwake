import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: KeepAwakeAppEnvironment?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set accessory policy as early as possible — before the run loop begins —
        // so RunningBoard never waits for a window that will never appear.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.makeEnvironment()
        self.environment = env
        Task {
            await env.controller.handleLaunch()
            // Show onboarding on first launch (after launch flow so the status item is visible).
            env.onboardingManager.showIfNeeded(settings: env.controller.settings)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Prompt the user before quitting if a session is active.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller = environment?.controller, controller.isActive else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "KeepAwake has an active session"
        alert.informativeText = "Quitting now will end the current session and allow your Mac to sleep normally. Are you sure you want to quit?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        // Icon
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return .terminateNow
        } else {
            return .terminateCancel
        }
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
