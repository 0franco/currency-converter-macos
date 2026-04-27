import AppKit
import CurrencyConverterMacOS
import SwiftUI

// MARK: - StatusBarController

/// Owns the `NSStatusItem`, manages the SwiftUI popover (left-click),
/// and attaches a context menu (right-click) with Refresh and Close actions.
@MainActor
final class StatusBarController: NSObject {

    // MARK: - Private properties

    private let statusItem: NSStatusItem
    private let popover: NSPopover

    /// Weak reference to the view model, used by right-click menu actions.
    private weak var viewModel: CurrencyConversionViewModel?

    // MARK: - Init

    init(viewModel: CurrencyConversionViewModel) {
        self.viewModel = viewModel

        // 1. Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // 2. Popover hosting the SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(viewModel: viewModel)
        )

        super.init()

        // 3. Configure the status bar button
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "dollarsign.arrow.circlepath",
                accessibilityDescription: "Currency Converter"
            )
            // Left-click action (toggles popover)
            button.action = #selector(handleButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    // MARK: - Button click handler

    /// Dispatches left-click (toggle popover) vs right-click (show context menu).
    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Popover

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(
                relativeTo: sender.bounds,
                of: sender,
                preferredEdge: .minY
            )
            // Bring app to front so the popover is key
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Context menu (right-click)

    private func showContextMenu(_ sender: NSStatusBarButton) {
        // Close popover before showing the menu (avoids layout overlap)
        if popover.isShown {
            popover.performClose(sender)
        }

        let menu = NSMenu()

        let refreshItem = NSMenuItem(
            title: "Refresh",
            action: #selector(handleRefresh),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let closeItem = NSMenuItem(
            title: "Close",
            action: #selector(handleClose),
            keyEquivalent: "q"
        )
        closeItem.target = self
        menu.addItem(closeItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so left-click continues to call our action selector
        statusItem.menu = nil
    }

    // MARK: - Menu actions

    @objc private func handleRefresh() {
        viewModel?.requestRefresh()
    }

    @objc private func handleClose() {
        NSApplication.shared.terminate(nil)
    }
}
