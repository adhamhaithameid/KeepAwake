# Manual Testing

## Menu Bar Basics

1. Launch `KeepAwake.app`.
2. Confirm the coffee icon appears in the menu bar.
3. **Left-click** the icon — icon switches to filled (active) state.
4. Left-click again — icon returns to outline (inactive) state.
5. **⌥ Option + click** the icon — confirms the *default* duration activates instantly without opening any menu.
6. Confirm a system notification appears when a session is stopped automatically (see Auto-Stop below).

## Right-Click Menu

1. **Right-click** the menu bar icon.
2. **Header** — confirm the live status indicator:
   - Green breathing dot when active; gray when inactive.
   - Countdown "1m 23s remaining" ticking down every second when a timed session is active.
   - Progress ring around the dot depleting over the session lifetime.
   - Battery line "Battery 87% — stops at 20%" appears when the battery threshold guard is enabled.
3. **Stop Now** item appears between the header and duration buttons only when a session is active.
4. Confirm quick buttons show the 3 pinned durations (default: `15m`, `1h`, `∞`).
5. Confirm **Activate for Duration** opens a submenu with non-pinned durations.
6. Confirm **Settings…** (⌘,) opens the settings window.
7. Confirm **Quit KeepAwake** (⌘Q) terminates the app.

## Settings Window

1. Right-click → **Settings…**.
2. Confirm the window comes to the front reliably.
3. Click anywhere on a full toggle row (not just the checkbox) — it should toggle.
4. Toggle **Deactivate Below Battery Threshold** on:
   - A continuous slider (1–100%) appears.
   - Drag freely to any value, e.g. 25%.
   - Drag near 10, 20, 50, 70, or 90% — the thumb should snap magnetically.
   - The readout turns **red** below 21%, **amber** 21–50%, **green** above 50%.
5. Toggle **Deactivate in Low Power Mode** on; enable Low Power Mode from System Settings.
   - Confirm any running session stops within 1–2 seconds.
   - Confirm a system notification appears.

## Activation Duration

1. Open the **Activation Duration** tab.
2. Click anywhere on a row (not just the label) to select it.
3. Tap the 📌 pin button to pin a duration — confirm the 3-pip counter increments.
4. Pin 3 durations — confirm the oldest pin is dropped when a 4th is added.
5. Open the right-click menu — confirm quick buttons reflect the current pins.
6. Add a custom duration, set it as default, remove it, reset to defaults.

## Auto-Stop Notifications

1. With a session active, enable Low Power Mode — confirm:
   - Session stops immediately (< 2 s).
   - A macOS notification "KeepAwake Stopped — Low Power Mode" appears.
2. Set battery threshold above current battery — start a session — confirm:
   - Session stops within 30 s.
   - A macOS notification "KeepAwake Stopped — battery below threshold" appears.

## About

1. Open the **About** tab.
2. Confirm the GitHub and Donate buttons open the correct links.
3. Confirm no Quit button is present on this tab (only appears on Settings / Duration tabs).
