import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let controller: KeepAwakeController
    private let statusItem: NSStatusItem
    /// The three "quick" durations always shown as buttons.
    private let quickDurations: [ActivationDuration] = [
        .minutes(15),
        .hours(1),
        .indefinite,
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
        let sfName = (name == "MenuBarCoffeeFilled") ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let sf = NSImage(systemSymbolName: sfName, accessibilityDescription: "KeepAwake") {
            return sf.withSymbolConfiguration(config) ?? sf
        }
        return nil
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        // Both left and right click open the menu
        if event.type == .leftMouseUp || event.type == .rightMouseUp {
            showMenu()
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        currentMenu = menu

        // ── Header row: status label + Quit button ──────────────────────────
        let headerItem = NSMenuItem()
        let headerView = MenuHeaderView(
            controller: controller,
            onQuit: { [weak self] in
                self?.currentMenu?.cancelTracking()
                Task {
                    await self?.controller.handleTermination()
                    NSApp.terminate(nil)
                }
            }
        )
        let headerHost = NSHostingView(rootView: headerView)
        headerHost.frame = NSRect(x: 0, y: 0, width: 252, height: 32)
        headerItem.view = headerHost
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // ── Quick duration buttons ─────────────────────────────────────────
        let quickItem = NSMenuItem()
        let quickView = QuickActionsMenuView(
            quickDurations: quickDurations,
            defaultDurationID: controller.settings.defaultDurationID,
            activate: { [weak self] duration in
                self?.activateFromMenu(duration)
            }
        )
        let quickHost = NSHostingView(rootView: quickView)
        // Height: 3 buttons = 88px, 4 buttons = 88px (wraps to 2 rows) → use fixed 88
        quickHost.frame = NSRect(x: 0, y: 0, width: 252, height: 88)
        quickItem.view = quickHost
        menu.addItem(quickItem)

        menu.addItem(.separator())

        // ── Overflow durations submenu ─────────────────────────────────────
        let quickIDs = Set(quickDurations.map(\.id))
        let overflowDurations = controller.settings.availableDurations.filter { !quickIDs.contains($0.id) }

        let durationSubmenuItem = NSMenuItem(title: "Activate for Duration", action: nil, keyEquivalent: "")
        durationSubmenuItem.isEnabled = true
        let durationSubmenu = NSMenu(title: "Activate for Duration")
        for duration in overflowDurations {
            let item = NSMenuItem(
                title: duration.menuTitle,
                action: #selector(handleDurationSelection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            item.isEnabled = true
            durationSubmenu.addItem(item)
        }
        durationSubmenuItem.submenu = durationSubmenu
        menu.addItem(durationSubmenuItem)

        menu.addItem(.separator())

        // ── Settings ───────────────────────────────────────────────────────
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

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
        // Slight delay so menu fully dismisses before window appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.controller.openSettings(selectedTab: .settings)
        }
    }
}

// MARK: - MenuHeaderView

/// Header bar shown at the top of the popover:
///   [status text ............... Quit ⌘Q]
private struct MenuHeaderView: View {
    @ObservedObject var controller: KeepAwakeController
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(controller.isActive ? Color.accentColor : Color.secondary)

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)

            Spacer()

            Button(action: onQuit) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusText: String {
        if controller.isActive, let session = controller.activeSession {
            return session.duration.isIndefinite
                ? "Active indefinitely"
                : "Active for \(session.duration.menuTitle)"
        }
        return "Inactive"
    }
}
