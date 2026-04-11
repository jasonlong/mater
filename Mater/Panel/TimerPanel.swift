import AppKit
import SwiftUI

final class TimerPanel: NSPanel {
    init(timerState: TimerState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 206),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let rootView = TimerPanelView(timerState: timerState)
        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
