import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let timerState = TimerState()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(timerState: timerState)
    }
}
