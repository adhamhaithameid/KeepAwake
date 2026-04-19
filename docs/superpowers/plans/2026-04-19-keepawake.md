# KeepAwake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new `KeepAwake` macOS 13+ menu bar app in `/Users/adhamhaithameid/Desktop/code/KeepAwake` by copying `KeepAwake`, preserving its install/release workflow, and replacing its runtime behavior with a wake-management utility.

**Architecture:** Copy the existing repo into a sibling folder, rename the project and release assets, then rebuild the app shell around `MenuBarExtra`, a dedicated settings window, wake-assertion services, and persisted duration/battery preferences. Keep the packaging scripts and About-page structure aligned with `KeepAwake`, while simplifying or replacing input-blocking-specific logic that no longer applies.

**Tech Stack:** Swift 6, SwiftUI, AppKit interop where needed, XcodeGen, xcodebuild, shell packaging scripts, XCTest.

---

### Task 1: Create The New Repository Skeleton

**Files:**
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/**`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/project.yml`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/README.md`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/script/*.sh`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake.xcodeproj/**` after generation

- [ ] **Step 1: Copy the repo into the new sibling folder**

```bash
rsync -a --exclude '.git' --exclude '.derived-data-release' --exclude '.release-checks' --exclude '.superpowers' \
  /Users/adhamhaithameid/Desktop/code/KeepAwake/ \
  /Users/adhamhaithameid/Desktop/code/KeepAwake/
```

- [ ] **Step 2: Initialize a fresh git repository for KeepAwake**

```bash
git init /Users/adhamhaithameid/Desktop/code/KeepAwake
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git checkout -b experimental/keepawake-foundation
```

- [ ] **Step 3: Rename the top-level product references from KeepAwake to KeepAwake**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
find . -depth \
  \( -name '*KeepAwake*' -o -name 'KeepAwake*' \) \
  -print
```

Expected: paths for the app folder, helper folder, xcodeproj, tests, resources, scripts, and docs that need renaming.

- [ ] **Step 4: Apply the rename sweep and regenerate the project**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodegen generate --spec project.yml
```

Expected: a generated `KeepAwake.xcodeproj` with renamed schemes/targets after the file edits land.

- [ ] **Step 5: Commit the copied and renamed scaffold**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "chore: scaffold KeepAwake from KeepAwake"
```

### Task 2: Replace The App Shell With A Menu Bar Architecture

**Files:**
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/App/KeepAwakeApp.swift`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/App/AppDelegate.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/App/AppEnvironment.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/MenuBarContentView.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/SettingsWindowView.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Support/AppTab.swift`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeTests/AppShellTests.swift`

- [ ] **Step 1: Write the failing tests for the new app shell state**

```swift
@MainActor
func test_default_tab_is_settings() {
    let model = KeepAwakeAppModel.preview()

    XCTAssertEqual(model.selectedTab, .settings)
}

@MainActor
func test_left_click_toggles_default_session_request() {
    let model = KeepAwakeAppModel.preview()

    model.handlePrimaryClick()

    XCTAssertEqual(model.lastRequestedDuration, .minutes(15))
    XCTAssertTrue(model.isActive)
}
```

- [ ] **Step 2: Run the shell tests and verify they fail for the missing types**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' -only-testing:KeepAwakeTests/AppShellTests test
```

Expected: FAIL because `KeepAwakeAppModel` and menu-bar app behavior are not implemented yet.

- [ ] **Step 3: Implement the minimal menu-bar app shell**

```swift
@main
struct KeepAwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppEnvironment.makeModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Label("KeepAwake", image: model.statusIconName)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("KeepAwake Settings", id: "settings") {
            SettingsWindowView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }
}
```

- [ ] **Step 4: Re-run the shell tests**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' -only-testing:KeepAwakeTests/AppShellTests test
```

Expected: PASS for the new shell tests.

- [ ] **Step 5: Commit the shell rewrite**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "feat: add menu bar app shell"
```

### Task 3: Implement Settings, Presets, And Duration Management

**Files:**
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Models/ActivationDuration.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Models/BatterySettings.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Models/AppSettings.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/SettingsTabView.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/ActivationDurationTabView.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/AddDurationSheet.swift`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeTests/AppSettingsTests.swift`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeTests/ActivationDurationStoreTests.swift`

- [ ] **Step 1: Write the failing settings persistence tests**

```swift
@MainActor
func test_default_duration_starts_at_fifteen_minutes() {
    let settings = AppSettings(userDefaults: UserDefaults(suiteName: #function)!)
    XCTAssertEqual(settings.defaultDuration, .minutes(15))
}

@MainActor
func test_custom_duration_can_be_added_and_selected_as_default() {
    let settings = AppSettings(userDefaults: UserDefaults(suiteName: #function)!)
    let custom = ActivationDuration(hours: 0, minutes: 45, seconds: 0)

    settings.addDuration(custom)
    settings.setDefaultDuration(custom.id)

    XCTAssertTrue(settings.availableDurations.contains(custom))
    XCTAssertEqual(settings.defaultDurationID, custom.id)
}
```

- [ ] **Step 2: Run the settings tests and verify they fail**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' \
  -only-testing:KeepAwakeTests/AppSettingsTests \
  -only-testing:KeepAwakeTests/ActivationDurationStoreTests test
```

Expected: FAIL because the new settings model and duration store do not exist yet.

- [ ] **Step 3: Implement the settings model and duration-management UI**

```swift
struct ActivationDuration: Codable, Equatable, Identifiable {
    let id: String
    let hours: Int
    let minutes: Int
    let seconds: Int

    var timeInterval: TimeInterval {
        TimeInterval((hours * 3600) + (minutes * 60) + seconds)
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var startAtLogin = false
    @Published var activateOnLaunch = false
    @Published var deactivateBelowThreshold = false
    @Published var batteryThreshold = 20
    @Published var deactivateOnLowPowerMode = false
    @Published var allowDisplaySleep = false
    @Published private(set) var availableDurations: [ActivationDuration]
    @Published var defaultDurationID: ActivationDuration.ID
}
```

- [ ] **Step 4: Re-run the settings tests**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' \
  -only-testing:KeepAwakeTests/AppSettingsTests \
  -only-testing:KeepAwakeTests/ActivationDurationStoreTests test
```

Expected: PASS for settings persistence and duration management.

- [ ] **Step 5: Commit the settings and duration work**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "feat: add settings and duration management"
```

### Task 4: Implement Wake Sessions And Safety Rules

**Files:**
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Services/WakeAssertionController.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Services/ActivationSessionController.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Services/BatteryMonitor.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Models/ActivationSession.swift`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/App/AppEnvironment.swift`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeTests/ActivationSessionControllerTests.swift`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeTests/BatteryMonitorTests.swift`

- [ ] **Step 1: Write the failing wake-session tests**

```swift
@MainActor
func test_starting_a_duration_replaces_the_existing_session() async {
    let assertions = RecordingWakeAssertionController()
    let controller = ActivationSessionController(assertions: assertions, batteryMonitor: .stub())

    await controller.start(.minutes(15), allowDisplaySleep: false)
    await controller.start(.hours(1), allowDisplaySleep: false)

    XCTAssertEqual(assertions.startCalls.count, 2)
    XCTAssertEqual(controller.activeSession?.duration, .hours(1))
}

@MainActor
func test_low_power_mode_rule_stops_the_session() async {
    let assertions = RecordingWakeAssertionController()
    let batteryMonitor = BatteryMonitor.stub(lowPowerModeEnabled: true)
    let controller = ActivationSessionController(assertions: assertions, batteryMonitor: batteryMonitor)

    await controller.start(.minutes(30), allowDisplaySleep: false, deactivateOnLowPowerMode: true)

    XCTAssertNil(controller.activeSession)
}
```

- [ ] **Step 2: Run the wake-session tests and verify they fail**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' \
  -only-testing:KeepAwakeTests/ActivationSessionControllerTests \
  -only-testing:KeepAwakeTests/BatteryMonitorTests test
```

Expected: FAIL because the wake/session layer is missing.

- [ ] **Step 3: Implement the wake assertions and session coordinator**

```swift
protocol WakeAssertionControlling {
    func activate(allowDisplaySleep: Bool) throws
    func deactivate()
}

@MainActor
final class ActivationSessionController: ObservableObject {
    @Published private(set) var activeSession: ActivationSession?

    func start(_ duration: ActivationDuration, allowDisplaySleep: Bool) async
    func stop(reason: StopReason) async
}
```

- [ ] **Step 4: Re-run the wake-session tests**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' \
  -only-testing:KeepAwakeTests/ActivationSessionControllerTests \
  -only-testing:KeepAwakeTests/BatteryMonitorTests test
```

Expected: PASS for session replacement, indefinite sessions, and auto-stop rules.

- [ ] **Step 5: Commit the session layer**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "feat: add wake session controller"
```

### Task 5: Finish Native UI, Branding, And About Page Parity

**Files:**
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/AboutTabView.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Views/KeepAwakeBranding.swift`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Resources/Assets.xcassets/MenuBarCoffeeOutline.imageset/*`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Resources/Assets.xcassets/MenuBarCoffeeFilled.imageset/*`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwake/Resources/Assets.xcassets/AppIcon.appiconset/*`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/README.md`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/docs/*.md`
- Test: `/Users/adhamhaithameid/Desktop/code/KeepAwake/KeepAwakeUITests/KeepAwakeUITests.swift`

- [ ] **Step 1: Write the failing UI-level tests for tab visibility and About actions**

```swift
func test_settings_window_shows_all_tabs() {
    let app = XCUIApplication()
    app.launchArguments = ["UITEST"]
    app.launch()

    XCTAssertTrue(app.buttons["tab.settings"].exists)
    XCTAssertTrue(app.buttons["tab.activationDuration"].exists)
    XCTAssertTrue(app.buttons["tab.about"].exists)
}
```

- [ ] **Step 2: Run the UI tests and verify they fail**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' -only-testing:KeepAwakeUITests test
```

Expected: FAIL because the final tabs, icons, and window content are not wired yet.

- [ ] **Step 3: Implement the finished UI and asset wiring**

```swift
enum AppTab: String, CaseIterable, Identifiable {
    case settings
    case activationDuration
    case about
}
```

Use native controls (`Toggle`, `Slider`, `List`, `Button`, `Form`) and keep the About layout closely aligned with the existing `KeepAwake` structure.

- [ ] **Step 4: Re-run the UI tests**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
xcodebuild -project KeepAwake.xcodeproj -scheme KeepAwake -destination 'platform=macOS' -only-testing:KeepAwakeUITests test
```

Expected: PASS for the tab visibility and settings-window presence checks.

- [ ] **Step 5: Commit the native UI pass**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "feat: finish native KeepAwake UI"
```

### Task 6: Preserve Build, Installer, And GitHub Delivery Flow

**Files:**
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/script/build_and_run.sh`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/script/make_installers.sh`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/script/run_release_checks.sh`
- Create: `/Users/adhamhaithameid/Desktop/code/KeepAwake/.codex/environments/environment.toml`
- Modify: `/Users/adhamhaithameid/Desktop/code/KeepAwake/project.yml`

- [ ] **Step 1: Write the failing packaging verification for renamed artifacts**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
./script/make_installers.sh
```

Expected: FAIL initially until all renamed app paths, resources, and verification checks match `KeepAwake`.

- [ ] **Step 2: Update the build/run/release scripts for KeepAwake**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
chmod +x script/build_and_run.sh script/make_installers.sh script/run_release_checks.sh
./script/build_and_run.sh --verify
```

Expected: the app builds and the process can be verified after the script updates land.

- [ ] **Step 3: Run the full release checks**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
./script/run_release_checks.sh
```

Expected: PASS with `KeepAwake.app`, renamed resources, and updated tests.

- [ ] **Step 4: Commit the packaging and tooling updates**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
git add .
git commit -m "build: restore KeepAwake release workflow"
```

- [ ] **Step 5: Create the GitHub repository and publish the branch history**

```bash
cd /Users/adhamhaithameid/Desktop/code/KeepAwake
gh auth status
gh repo create KeepAwake --public --source=. --remote=origin --push
```

Expected: a new GitHub repository with the local commit history pushed.
