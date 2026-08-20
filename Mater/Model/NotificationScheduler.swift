import AppKit
import Foundation
import os
import UserNotifications

@MainActor
protocol CycleNotificationScheduling: AnyObject {
    func cycleCompleted(_ completedMode: TimerMode) async
}

/// Delivers cycle completion notifications through the system notification
/// center. Notifications are marked time-sensitive so they can break through
/// Focus modes and full-screen apps when the user allows it.
@MainActor
final class SystemNotificationScheduler: NSObject, CycleNotificationScheduling, UNUserNotificationCenterDelegate {
    private static let logger = Logger(subsystem: "me.jasonlong.mater", category: "notifications")

    private let preferences: AppPreferences
    private let center: UNUserNotificationCenter

    init(preferences: AppPreferences, center: UNUserNotificationCenter = .current()) {
        self.preferences = preferences
        self.center = center
        super.init()
        center.delegate = self
    }

    func cycleCompleted(_ completedMode: TimerMode) async {
        guard preferences.notificationsEnabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        switch completedMode {
        case .working:
            content.title = Localization.shared.string("notification.workComplete.title")
            content.body = Localization.shared.string("notification.workComplete.body", preferences.breakMinutes)
        case .breaking:
            content.title = Localization.shared.string("notification.breakComplete.title")
            content.body = Localization.shared.string("notification.breakComplete.body", preferences.workMinutes)
        case .stopped:
            return
        }
        content.interruptionLevel = .timeSensitive
        // The app already plays its own ding sound; only attach a notification
        // sound when in-app sounds are muted.
        content.sound = preferences.soundEnabled ? nil : .default

        let request = UNNotificationRequest(
            identifier: "mater.cycle.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Failed to deliver cycle notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even when Mater is the frontmost app.
        completionHandler([.banner, .sound])
    }
}

enum NotificationPermission {
    private static let logger = Logger(subsystem: "me.jasonlong.mater", category: "notifications")

    @MainActor
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .timeSensitive])
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            logger.error("Failed to build notification settings URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
