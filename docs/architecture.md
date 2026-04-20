# Architecture

KeepAwake is a menu bar utility built around macOS power assertions.

## Core Pieces

### `WakeAssertionController`

Creates and releases IOKit power assertions that prevent system and/or display sleep.

### `ActivationSessionController`

Tracks the active session, runs a timed expiration task, and monitors power conditions via:
- A **30-second poll** for battery level and Low Power Mode.
- A **reactive `NSProcessInfoPowerStateDidChange` notification observer** that reacts to Low Power Mode changes within milliseconds — no waiting for the next poll.

When a session is stopped automatically the controller sets `lastStopReason` so `KeepAwakeController` can fire a system notification.

### `NotificationManager`

Wraps `UNUserNotificationCenter`. Requests notification permission at launch and delivers an alert+sound when a session is stopped automatically (Low Power Mode, battery threshold, or expiry). Manual stops are silent.

### `AppSettings`

Persists all user preferences to `UserDefaults`:

| Key | Type | Notes |
|-----|------|-------|
| `activateOnLaunch` | Bool | Start default session on app launch |
| `deactivateBelowThreshold` | Bool | Enable battery guard |
| `batteryThreshold` | Int 1–100 | Any value; UI applies magnetic snapping near anchor points |
| `deactivateOnLowPowerMode` | Bool | Reactive stop via notification |
| `allowDisplaySleep` | Bool | Keep Mac awake / let display sleep |
| `defaultDurationID` | String | ID of the left-click default duration |
| `pinnedDurationIDs` | [String] | Up to 3 IDs shown as quick buttons in the menu |

The battery threshold **slider is free-range (1–100%)** with *magnetic snap points* at 10, 20, 50, 70, and 90%. `AppSettings.applyMagneticSnap(_:)` implements the snapping logic.

### `StatusItemController`

Owns the NSStatusItem and drives all click behaviour:

| Click | Action |
|-------|--------|
| Left click | Toggle active/inactive (default duration) |
| ⌥ Option + click | Activate default duration instantly (no menu) |
| Right click / Ctrl + click | Open the pop-up menu |

The menu header (`MenuHeaderView`) is driven by `TimelineView(.periodic(from:by:1))` so the countdown and progress ring redraw every second without a manual timer. The `PulsingDot` uses a repeating `easeInOut` scale + expanding outer glow ring to feel alive.

When a session is active the menu also shows a **"Stop Now"** item directly below the header.

### `SettingsWindowManager`

Creates one stable `NSHostingController` on init and reuses it for all subsequent `show()` calls so SwiftUI state and bindings are never torn down. Uses `orderFrontRegardless()` + `NSApp.activate` to reliably bring the window to front for `LSUIElement` (menu-bar-only) apps.

## Why No Special Permissions?

KeepAwake does not intercept input devices. It only manages sleep prevention, which requires only native power-management APIs (no Accessibility or Input Monitoring entitlements needed).
