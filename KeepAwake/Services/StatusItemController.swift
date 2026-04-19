import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let controller: KeepAwakeController
    private let statusItem: NSStatusItem
    private let quickDurationIDs: Set<ActivationDuration.ID> = [
        ActivationDuration.minutes(15).id,
        ActivationDuration.hours(1).id,
        ActivationDuration.indefinite.id,
    ]
    private var currentMenu: NSMenu?
    private var cancellables: Set<AnyCancellable> = []

    init(controller: KeepAwakeController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        observeController()
        refreshAppearance()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.imagePosition = .imageOnly
        button.toolTip = "KeepAwake"
        button.imageScaling = .scaleProportionallyDown
        _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeController() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshAppearance()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshAppearance() {
        guard let button = statusItem.button else { return }
        button.image = makeStatusImage(named: controller.statusIconName)
    }

    private func makeStatusImage(named name: String) -> NSImage? {
        guard let source = NSImage(named: NSImage.Name(name)),
              let image = source.copy() as? NSImage else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private var overflowDurations: [ActivationDuration] {
        controller.settings.availableDurations.filter { !quickDurationIDs.contains($0.id) }
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            showMenu()
            return
        }

        Task { await controller.handlePrimaryClick() }
    }

    private func showMenu() {
        let menu = NSMenu()
        currentMenu = menu

        if controller.isActive, let session = controller.activeSession {
            let stateItem = NSMenuItem(
                title: session.duration.isIndefinite ? "Currently active indefinitely" : "Currently active for \(session.duration.menuTitle)",
                action: nil,
                keyEquivalent: ""
            )
            stateItem.isEnabled = false
            menu.addItem(stateItem)
            menu.addItem(.separator())
        }

        let quickActionsItem = NSMenuItem()
        let quickActionsView = QuickActionsMenuView { [weak self] duration in
            self?.activateFromMenu(duration)
        }
        let hostingView = NSHostingView(rootView: quickActionsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 228, height: 82)
        quickActionsItem.view = hostingView
        menu.addItem(quickActionsItem)
        menu.addItem(.separator())

        let durationSubmenuItem = NSMenuItem(title: "Activate for Duration", action: nil, keyEquivalent: "")
        let durationSubmenu = NSMenu(title: "Activate for Duration")
        for duration in overflowDurations {
            let item = NSMenuItem(title: duration.menuTitle, action: #selector(handleDurationSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration
            durationSubmenu.addItem(item)
        }
        durationSubmenuItem.submenu = durationSubmenu
        menu.addItem(durationSubmenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "Settings"
        )
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(
            systemSymbolName: "power",
            accessibilityDescription: "Quit"
        )
        menu.addItem(quitItem)

        statusItem.popUpMenu(menu)
        currentMenu = nil
        refreshAppearance()
    }

    private func activateFromMenu(_ duration: ActivationDuration) {
        currentMenu?.cancelTracking()
        Task { await controller.activate(duration: duration) }
    }

    @objc
    private func handleDurationSelection(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? ActivationDuration else { return }
        activateFromMenu(duration)
    }

    @objc
    private func openSettings() {
        currentMenu?.cancelTracking()
        controller.openSettings(selectedTab: .settings)
    }

    @objc
    private func quitApp() {
        currentMenu?.cancelTracking()
        Task {
            await controller.handleTermination()
            NSApp.terminate(nil)
        }
    }
}
