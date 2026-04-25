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
    ///
    /// ## Two code paths — chosen based on whether a window is currently key
    ///
    /// **Path A — Key window exists (e.g. Settings is open):**
    /// A regular AppKit window is present and owns the event loop, so
    /// `alert.runModal()` works synchronously. Return `.terminateNow` or
    /// `.terminateCancel` directly.
    ///
    /// **Path B — No key window (pure menu-bar / LSUIElement state):**
    /// There is no window driving the event loop. `alert.runModal()` would
    /// hang forever because the nested modal loop never receives events.
    /// Fix: return `.terminateLater`, temporarily switch to `.regular` activation
    /// policy so the alert window can become key, run the modal, then call
    /// `NSApp.reply(toApplicationShouldTerminate:)` with the user's choice.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller = environment?.controller, controller.isActive else {
            return .terminateNow
        }

        if NSApp.keyWindow != nil {
            // Path A: A window is key — runModal works fine synchronously.
            let response = makeQuitAlert().runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }

        // Path B: No key window — use async .terminateLater flow.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            let response = self.makeQuitAlert().runModal()
            NSApp.setActivationPolicy(.accessory)
            NSApp.reply(toApplicationShouldTerminate: response == .alertFirstButtonReturn)
        }
        return .terminateLater
    }

    private func makeQuitAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "KeepAwake has an active session"
        alert.informativeText = "Quitting will end the current session and allow your Mac to sleep normally. Quit anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        if let icon = NSApp.applicationIconImage { alert.icon = icon }
        return alert
    }


    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous teardown — no async/await or DispatchSemaphore here.
        //
        // applicationWillTerminate is called on the main thread while AppKit
        // holds the run loop. Using DispatchSemaphore.wait() or await on a
        // @MainActor method both deadlock: the Task can never run because the
        // main thread is blocked waiting for it to finish.
        //
        // terminateSync() cancels Swift Tasks (non-blocking) and releases the
        // IOKit power assertion synchronously via IOPMAssertionRelease — which
        // is all that is needed before the process exits.
        environment?.controller.terminateSync()
    }
}
