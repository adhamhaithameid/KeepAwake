# Permissions

KeepAwake does **not** require Accessibility, Input Monitoring, or Screen Recording permissions.

The app uses macOS power-management assertions to keep the system awake, which works without any of the high-privilege input-monitoring permissions some other utility apps need.

## What You Might Still See

### Start At Login Approval

If you enable **Start at login**, macOS may show its normal background-item or login-item approval UI. That is expected and is handled by the operating system.

### Battery And Power State

If you enable battery-aware rules, KeepAwake reads:

- current battery percentage
- Low Power Mode state

This information stays local to your Mac and is used only to decide when to stop an active session.
