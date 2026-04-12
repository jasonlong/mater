import AppKit
import SwiftUI

#if DEBUG
@MainActor @Observable
final class DebugState {
    var showTime = false
}
#endif

final class TimerPanel: NSPanel {
    #if DEBUG
    private let debugState = DebugState()
    #endif

    init(timerState: TimerState, showSettings: @escaping () -> Void) {
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

        #if DEBUG
        let rootView = TimerPanelView(timerState: timerState, showSettings: showSettings, debugState: debugState)
        #else
        let rootView = TimerPanelView(timerState: timerState, showSettings: showSettings)
        #endif
        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    #if DEBUG
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "d" {
            debugState.showTime.toggle()
        } else {
            super.keyDown(with: event)
        }
    }
    #endif
}
