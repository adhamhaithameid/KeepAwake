# Architecture

KeepAwake is a menu bar utility built around macOS power assertions.

## Core Pieces

### `WakeAssertionController`

Creates and releases the IOKit power assertions that keep the Mac awake.

### `ActivationSessionController`

Tracks the active session, handles timed expiration, and stops sessions when battery rules or Low Power Mode rules are triggered.

### `AppSettings`

Stores:

- login behavior
- launch behavior
- battery rules
- display sleep preference
- duration list
- saved default duration

### `StatusItemController`

Owns the menu bar status item, updates the coffee icon, handles left-click toggle behavior, and shows the right-click menu.

### `SettingsWindowManager`

Creates and reuses the settings window built with SwiftUI.

## Why No Special Permissions?

KeepAwake does not intercept input devices. It only manages sleep prevention, which means it can rely on native power-management APIs instead of Accessibility and Input Monitoring.
