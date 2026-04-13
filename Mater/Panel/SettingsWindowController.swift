import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: AppPreferences

    init(preferences: AppPreferences) {
        self.preferences = preferences
        let hostingController = NSHostingController(
            rootView: SettingsView(preferences: preferences)
        )

        super.init(window: nil)
        self.window = Self.makeWindow(contentViewController: hostingController)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .preference
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }
}
