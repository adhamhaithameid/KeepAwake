import AppKit
import SwiftUI

@MainActor
protocol SettingsWindowManaging: AnyObject {
    func show(selectedTab: AppTab)
}

@MainActor
final class SettingsWindowManager: SettingsWindowManaging {
    private let rootViewProvider: () -> SettingsWindowView
    private var window: NSWindow?

    init(rootViewProvider: @escaping () -> SettingsWindowView) {
        self.rootViewProvider = rootViewProvider
    }

    func show(selectedTab: AppTab) {
        let rootView = rootViewProvider()
        let hostingController = NSHostingController(rootView: rootView)

        if let window {
            window.contentViewController = hostingController
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = "KeepAwake"
        window.setContentSize(NSSize(width: 620, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .unifiedCompact
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
}
