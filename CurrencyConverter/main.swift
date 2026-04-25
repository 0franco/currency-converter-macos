import AppKit

// Top-level code in main.swift is NOT implicitly @MainActor in Swift 6
// when the type is nonisolated. We construct AppDelegate (which is nonisolated)
// and immediately hand it to NSApplication before calling run().
// AppKit itself ensures delegate callbacks happen on the main thread.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApp.run()
