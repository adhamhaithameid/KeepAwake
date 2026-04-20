import AppKit

// Explicit entry point — replaces @main on AppDelegate.
// This avoids Swift 6 strict-concurrency conflicts between
// the @MainActor-isolated AppDelegate and the NSApplicationDelegate
// protocol methods, which AppKit calls from the main thread but
// whose signatures are not MainActor-annotated in the SDK.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
