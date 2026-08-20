import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = AppPreferences()
    lazy var timerState = TimerState(preferences: preferences)
    private var statusItemController: StatusItemController?
    private lazy var settingsWindowController = SettingsWindowController(preferences: preferences)
    private var notificationScheduler: SystemNotificationScheduler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Localization.shared.configure(preferences: preferences)

        let scheduler = SystemNotificationScheduler(preferences: preferences)
        notificationScheduler = scheduler
        timerState.addCycleCompleteObserver { [weak scheduler] completedMode in
            Task { @MainActor in
                await scheduler?.cycleCompleted(completedMode)
            }
        }

        statusItemController = StatusItemController(
            timerState: timerState,
            showSettings: { [weak self] in
                self?.settingsWindowController.show()
            }
        )
    }
}
