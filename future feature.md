# Future Features

Planned ideas for future implementation, grouped by area.

## Session Experience

- Add one-click **Extend** options in the menu (`+15m`, `+30m`, `+1h`) while a session is active.

## Automation and Smart Triggers

- Add **Calendar-based auto-activation** (start before meetings, stop when meeting ends).
- Add **charger-aware rules** (different behavior on battery vs plugged in).
- Add **network-aware rules** (e.g., auto-activate on specific Wi-Fi networks).
- Add optional **auto-stop when screen sharing ends** (currently start-only behavior).

## Menu Bar and Settings UX

- Add a **Dock icon visibility toggle** for users who want easier app switching.
- Add alternative menu bar icon styles and let users choose in Settings.
- Add customizable quick actions count (3/4/5) instead of fixed pinned count.
- Add keyboard shortcuts for common actions (start default, stop, open settings).
- Rework Settings into a **left-sidebar navigation layout** for faster scanning.

## Durations and Profiles

- Allow reordering durations with drag-and-drop.
- Add optional iCloud sync for settings across Macs.
- Support per-trigger default durations (e.g., Focus = 1h, Screen Share = 2h).

## Notifications and Feedback

- Add user-configurable pre-end warning times (1m, 5m, 10m).
- Add a clear in-app notification status indicator (authorized/disabled).
- Add richer auto-stop reasons in notifications with suggested fixes.

## Reliability and Quality

- Expand tests for Focus/screen-sharing automation edge cases.
- Add deterministic tests for app termination and assertion cleanup paths.
- Add snapshot/UI tests for menu and settings interactions.
- Add CI checks to catch docs/tests drift and API signature mismatches early.
- Add structured regression test plans per release.

## Privacy, Safety, and Performance Hardening

- Add stronger guardrails around unsupported/unknown power-state readings.
- Add resilience for rapid trigger flapping (debounce/coalesce automation events).
- Add lightweight telemetry logs (local only) for debugging wake assertion failures.
- Benchmark CPU and memory impact of 1-second UI updates and animation loops.
- Add startup and idle performance budgets with regression alerts.

## Docs and Release Hygiene

- Add a release checklist that validates docs against current behavior.
- Keep changelog generation tied to current features to avoid product drift.
- Add a “Known Limitations” doc section for automation caveats and OS quirks.
- Add migration notes when changing settings keys/defaults.

## Branding

- Design and ship a new KeepAwake logo (including app icon and menu bar variants).
