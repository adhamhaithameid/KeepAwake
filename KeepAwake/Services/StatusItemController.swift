import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let controller: KeepAwakeController
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []

    init(controller: KeepAwakeController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        observeController()
        refreshAppearance()
    }

    // MARK: - Setup

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
                DispatchQueue.main.async { self?.refreshAppearance() }
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
        return NSImage(systemSymbolName: sfName, accessibilityDescription: "KeepAwake")?
            .withSymbolConfiguration(config)
    }

    // MARK: - Click handling

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = event.type == .rightMouseUp
        let isCtrlLeft = event.type == .leftMouseUp && event.modifierFlags.contains(.control)

        if isRightClick || isCtrlLeft {
            showMenu()
        } else {
            // Left click → toggle active state
            Task { await controller.handlePrimaryClick() }
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = buildMenu()
        // Canonical trick: set menu on status item so the system's standard
        // event loop correctly routes clicks to NSHostingView custom items.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        refreshAppearance()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // ── Visual status header ──────────────────────────────────────────
        let headerItem = NSMenuItem()
        let headerHost = NSHostingView(rootView: MenuHeaderView(controller: controller))
        headerHost.frame = NSRect(x: 0, y: 0, width: 252, height: 36)
        headerItem.view = headerHost
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // ── Pinned quick-duration buttons ─────────────────────────────────
        let pinnedDurations = resolvedPinnedDurations()
        let quickItem = NSMenuItem()
        let quickView = QuickActionsMenuView(
            quickDurations: pinnedDurations,
            defaultDurationID: controller.settings.defaultDurationID,
            activate: { [weak self] duration in self?.activateFromMenu(duration) }
        )
        let quickHost = NSHostingView(rootView: quickView)
        quickHost.frame = NSRect(x: 0, y: 0, width: 252, height: 88)
        quickItem.view = quickHost
        menu.addItem(quickItem)

        menu.addItem(.separator())

        // ── Overflow durations submenu ─────────────────────────────────────
        let pinnedIDs = Set(pinnedDurations.map(\.id))
        let overflowDurations = controller.settings.availableDurations
            .filter { !pinnedIDs.contains($0.id) }

        if !overflowDurations.isEmpty {
            let submenuItem = NSMenuItem(title: "Activate for Duration", action: nil, keyEquivalent: "")
            submenuItem.isEnabled = true
            let submenu = NSMenu(title: "Activate for Duration")
            for duration in overflowDurations {
                let item = NSMenuItem(
                    title: duration.menuTitle,
                    action: #selector(handleDurationSelection(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = duration
                item.isEnabled = true
                submenu.addItem(item)
            }
            submenuItem.submenu = submenu
            menu.addItem(submenuItem)
            menu.addItem(.separator())
        }

        // ── Settings ──────────────────────────────────────────────────────
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        // ── Quit (directly below Settings, no extra separator) ─────────────
        let quitItem = NSMenuItem(title: "Quit KeepAwake", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Helpers

    /// Resolves the 3 pinned duration objects. If fewer than 3 are pinned,
    /// fills with defaults. Includes the default duration as an extra button
    /// if it differs from all pinned ones (handled in QuickActionsMenuView).
    private func resolvedPinnedDurations() -> [ActivationDuration] {
        let available = controller.settings.availableDurations
        let pinIDs = controller.settings.pinnedDurationIDs
        return pinIDs.compactMap { id in available.first { $0.id == id } }
    }

    // MARK: - Actions

    private func activateFromMenu(_ duration: ActivationDuration) {
        Task { await controller.activate(duration: duration) }
    }

    @objc
    private func handleDurationSelection(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? ActivationDuration else { return }
        activateFromMenu(duration)
    }

    @objc
    private func openSettings() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.controller.openSettings(selectedTab: .settings)
        }
    }

    @objc
    private func quitApp() {
        Task {
            await controller.handleTermination()
            NSApp.terminate(nil)
        }
    }
}

// MARK: - MenuHeaderView

/// Centered status row with a traffic-light-style dot for instant
/// active / inactive recognition without reading any text.
private struct MenuHeaderView: View {
    @ObservedObject var controller: KeepAwakeController

    private var isActive: Bool { controller.isActive }

    var body: some View {
        HStack(spacing: 7) {
            // Colored status dot
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.25) : Color.secondary.opacity(0.15))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
            }

            // Status text
            VStack(alignment: .leading, spacing: 1) {
                Text(isActive ? "Active" : "Inactive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.green : Color.secondary)
                if let detail = detailText {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
    }

    private var detailText: String? {
        guard isActive, let session = controller.activeSession else { return nil }
        if session.duration.isIndefinite { return "Indefinitely" }
        if let endsAt = session.endsAt {
            let remaining = endsAt.timeIntervalSinceNow
            if remaining > 0 {
                let mins = Int(remaining / 60)
                let secs = Int(remaining) % 60
                return mins > 0 ? "\(mins)m \(secs)s remaining" : "\(secs)s remaining"
            }
        }
        return "Started \(session.duration.menuTitle) ago"
    }
}
