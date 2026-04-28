import AppKit
import SwiftUI

@MainActor
protocol SettingsWindowManaging: AnyObject {
    func show(selectedTab: AppTab)
}

@MainActor
final class SettingsWindowManager: NSObject, SettingsWindowManaging, NSWindowDelegate {
    // Keep ONE stable hosting controller so SwiftUI state and bindings
    // are never torn down between calls to show().
    private let hostingController: NSHostingController<SettingsWindowView>
    private var window: NSWindow?

    init(rootViewProvider: @escaping () -> SettingsWindowView) {
        self.hostingController = NSHostingController(rootView: rootViewProvider())
    }

    func show(selectedTab: AppTab) {
        if let existing = window {
            // Window already exists — just bring it forward.
            existing.orderFrontRegardless()
            // Also try normal activation path
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let win = NSWindow(contentViewController: hostingController)
        win.title = "KeepAwake"
        win.setContentSize(NSSize(width: 640, height: 540))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.toolbarStyle = .unifiedCompact
        // Prevent the user from shrinking the window until the layout breaks (UX-3).
        win.minSize = NSSize(width: 480, height: 420)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        // orderFrontRegardless brings the window to front even for
        // LSUIElement (menu-bar-only) apps where NSApp.activate alone
        // may not reliably front the window.
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    // MARK: - NSWindowDelegate

    /// Nil out our reference when the user closes the window (SE-2).
    /// Without this the window object stays alive in memory and the next call
    /// to show() returns the existing-but-closed window instead of creating a
    /// fresh one, causing the settings panel to never reopen.
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
        }
    }
}
