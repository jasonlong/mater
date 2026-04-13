import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = AppPreferences()
    lazy var timerState = TimerState(preferences: preferences)
    private var statusItemController: StatusItemController?
    private lazy var settingsWindowController = SettingsWindowController(preferences: preferences)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            timerState: timerState,
            showSettings: { [weak self] in
                self?.settingsWindowController.show()
            }
        )
    }
}
