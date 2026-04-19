# Install Guide

## Download a Ready-Made Build

1. Go to the [Releases page](https://github.com/adhamhaithameid/KeepAwake/releases).
2. Download either:
   - the **`.dmg`** — drag-to-Applications installer window
   - the **`.zip`** — plain archive, move `KeepAwake.app` to Applications yourself
3. If macOS warns about an unsigned app, right-click `KeepAwake.app` → **Open** → click **Open** in the dialog.

## First Launch

When you open KeepAwake for the first time, a one-time setup screen appears:

1. **Grant Accessibility** — click the button, toggle KeepAwake ON in System Settings.
2. **Grant Input Monitoring** — click the button, add KeepAwake and toggle it ON.
3. Both permissions turn green once detected. Click **Continue to KeepAwake**.

> **Tip:** If Input Monitoring doesn't turn green even after you granted it, click **"I've Already Granted It"** — this can happen with unsigned builds and is harmless.

## Your First Clean

1. Go to the **Clean** tab.
2. Click **Disable Keyboard**.
3. Clean your keyboard while the trackpad stays active.
4. Click **Re-enable Keyboard** when you're done.

That's it. For a more thorough test, run the [Post-Install Checklist](manual-testing.md).

## Build From Source

If you prefer building from source:

```bash
git clone https://github.com/adhamhaithameid/KeepAwake.git
cd KeepAwake
xcodegen generate
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -configuration Release build
```

**Requirements:** macOS 13.0+ · Xcode 15+ · [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## If Something Goes Wrong

- [Permissions](permissions.md) — if macOS blocks the cleaning actions.
- [Troubleshooting](troubleshooting.md) — if the app opens but doesn't behave as expected.
