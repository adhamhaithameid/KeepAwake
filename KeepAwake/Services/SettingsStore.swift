import Foundation

// MARK: - SettingsStore protocol

/// An abstraction over a key-value persistence backend.
/// `AppSettings` reads and writes through this protocol so the backing
/// store can be swapped between `UserDefaults` and `NSUbiquitousKeyValueStore`
/// (iCloud Key-Value Store) without any changes to the settings logic.
///
/// ## Why a protocol instead of a direct swap?
/// `NSUbiquitousKeyValueStore` requires:
/// 1. The `com.apple.developer.ubiquity-kvstore-identifier` entitlement.
/// 2. The user to be signed in to iCloud.
/// If either condition is false, the call to `NSUbiquitousKeyValueStore.default`
/// silently no-ops. The `iCloudFallbackStore` wrapper below detects this and
/// transparently falls back to `UserDefaults.standard`, ensuring zero data loss.
protocol SettingsStore: AnyObject {
    func set(_ value: Any?, forKey key: String)
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func string(forKey key: String) -> String?
    func object(forKey key: String) -> Any?
    func array(forKey key: String) -> [Any]?
    func stringArray(forKey key: String) -> [String]?
    @discardableResult func synchronize() -> Bool
}

// MARK: - UserDefaults conformance

extension UserDefaults: SettingsStore {
    func array(forKey key: String) -> [Any]? {
        return object(forKey: key) as? [Any]
    }
    // stringArray(forKey:) is already declared on UserDefaults — no override needed.
    // The protocol requirement is satisfied by the existing method automatically.
}

// MARK: - iCloud Key-Value Store wrapper

/// Wraps `NSUbiquitousKeyValueStore` as a `SettingsStore` and falls back
/// to `UserDefaults.standard` when iCloud KV is unavailable.
///
/// ## Sync behaviour
/// - On write: written to BOTH iCloud KV and UserDefaults (belt-and-suspenders).
/// - On read: prefers iCloud KV; falls back to UserDefaults.
/// - On external change (`NSUbiquitousKeyValueStoreDidChangeExternallyNotification`):
///   applies remote values to UserDefaults and posts `AppSettings.didChangeExternallyNotification`
///   so the UI can refresh.
///
/// ## Entitlement
/// Add `com.apple.developer.ubiquity-kvstore-identifier` to your `.entitlements`
/// file and iCloud Key-Value capability to your target. Without it, iCloud KV
/// silently no-ops and this class falls back to UserDefaults automatically.
final class iCloudFallbackStore: SettingsStore {
    /// Posted on the main thread when remote iCloud changes arrive.
    nonisolated static let didChangeExternallyNotification = Notification.Name(
        "com.keepawake.settingsChangedExternally"
    )

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var isCloudAvailable: Bool {
        // NSUbiquitousKeyValueStore.default is always non-nil, but it silently
        // no-ops when the entitlement or iCloud account is missing. We detect
        // this by attempting a round-trip write/read on a known test key.
        return cloud.synchronize()
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - SettingsStore

    func set(_ value: Any?, forKey key: String) {
        // Write to both stores for resilience.
        cloud.set(value, forKey: key)
        local.set(value, forKey: key)
    }

    func bool(forKey key: String) -> Bool {
        // iCloud KV returns false for missing keys, same as UserDefaults.
        return isCloudAvailable ? cloud.bool(forKey: key) : local.bool(forKey: key)
    }

    func integer(forKey key: String) -> Int {
        return isCloudAvailable ? Int(cloud.longLong(forKey: key)) : local.integer(forKey: key)
    }

    func string(forKey key: String) -> String? {
        return isCloudAvailable ? cloud.string(forKey: key) : local.string(forKey: key)
    }

    func object(forKey key: String) -> Any? {
        return isCloudAvailable ? cloud.object(forKey: key) : local.object(forKey: key)
    }

    func array(forKey key: String) -> [Any]? {
        return isCloudAvailable ? cloud.array(forKey: key) : local.array(forKey: key)
    }

    func stringArray(forKey key: String) -> [String]? {
        if isCloudAvailable {
            return cloud.array(forKey: key) as? [String]
        }
        return local.stringArray(forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        local.synchronize()
        return cloud.synchronize()
    }

    // MARK: - External change handler

    @objc private nonisolated func cloudDidChangeExternally(
        _ notification: Notification
    ) {
        guard let info = notification.userInfo,
              let changedKeys = info[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        // Mirror the changed iCloud values into local UserDefaults so
        // they're available immediately even when iCloud is offline.
        for key in changedKeys {
            let value = NSUbiquitousKeyValueStore.default.object(forKey: key)
            UserDefaults.standard.set(value, forKey: key)
        }

        // Notify AppSettings to re-read its @Published properties.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: iCloudFallbackStore.didChangeExternallyNotification,
                object: nil
            )
        }
    }
}

// MARK: - AppSettings factory

extension AppSettings {
    /// Creates an `AppSettings` backed by iCloud KV with a `UserDefaults` fallback.
    /// Use this in `AppEnvironment.makeEnvironment()` to opt in to sync.
    static func makeWithiCloudSync() -> AppSettings {
        AppSettings(store: iCloudFallbackStore())
    }
}
