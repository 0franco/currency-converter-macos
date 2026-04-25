import AppKit
import CurrencyConverterMacOS

// MARK: - AppDelegate

/// Application delegate. AppKit guarantees all `NSApplicationDelegate` callbacks
/// are called on the main thread. We annotate `applicationDidFinishLaunching`
/// with `@MainActor` so Swift 6 allows it to construct `@MainActor`-isolated
/// types (`AppComposition`, `StatusBarController`) without warnings.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // These are set once in applicationDidFinishLaunching (main thread) and
    // never mutated again. `nonisolated(unsafe)` satisfies Swift 6's requirement
    // that stored properties of a nonisolated class be nonisolated too.
    nonisolated(unsafe) private var composition: AppComposition?
    nonisolated(unsafe) private var statusBarController: StatusBarController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the Dock — this is a menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)

        let comp = AppComposition()
        composition = comp
        statusBarController = StatusBarController(viewModel: comp.viewModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
