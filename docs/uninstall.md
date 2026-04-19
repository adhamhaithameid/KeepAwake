# Uninstall KeepAwake

If you decide to remove KeepAwake, it takes about 30 seconds.

## 1. Quit the App

If KeepAwake is open, close the window. It fully quits automatically.

## 2. Delete the App

Drag `KeepAwake.app` from your **Applications** folder to the Trash.

## 3. Remove Permissions (Optional)

If you want to clean up the permission entries:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Select KeepAwake and click the **−** button.
3. Repeat in **Input Monitoring**.

## 4. Remove Preferences (Optional)

KeepAwake stores a small preferences file with your timer duration and auto-start setting. To remove it:

```bash
defaults delete com.adhamhaithameid.keepawake
```

## 5. Remove Build Artifacts (If You Built From Source)

If you cloned the repository and built locally, you can delete these generated folders:

```
release/
.release-checks/
.derived-data/
.derived-data-release/
dist/
```

That's it — KeepAwake leaves nothing else behind.
