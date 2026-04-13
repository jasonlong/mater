import AppKit
import SwiftUI

#if DEBUG
@MainActor @Observable
final class DebugState {
    var showTime = false
}
#endif

final class TimerPanel: NSPanel {
    private let timerState: TimerState
    #if DEBUG
    private let debugState = DebugState()
    #endif

    init(timerState: TimerState, showSettings: @escaping () -> Void) {
        self.timerState = timerState
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
    override var acceptsMouseMovedEvents: Bool { get { true } set {} }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case " ":
            timerState.toggle()
        #if DEBUG
        case "d":
            debugState.showTime.toggle()
        #endif
        default:
            super.keyDown(with: event)
        }
    }
}
